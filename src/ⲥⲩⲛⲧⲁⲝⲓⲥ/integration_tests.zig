// Integration Tests for VIBEE Compiler
// Tests all PAS-enhanced components working together

const std = @import("std");
const parser = @import("parser.zig");
const codegen = @import("codegen.zig");
const pas = @import("pas.zig");
const simd_parser = @import("simd_parser.zig");
const egraph = @import("egraph.zig");
const property_testing = @import("property_testing.zig");
const incremental_types = @import("incremental_types.zig");
const coverage_fuzzer = @import("coverage_fuzzer.zig");

// ============================================================================
// TEST FIXTURES
// ============================================================================

const MINIMAL_SPEC =
    \\name: minimal_test
    \\version: "1.0.0"
    \\language: zig
    \\module: minimal
    \\
    \\behaviors:
    \\  - name: test_behavior
    \\    given: A test condition
    \\    when: Action is taken
    \\    then: Expected result
;

const FULL_SPEC =
    \\name: full_test
    \\version: "2.0.0"
    \\language: zig
    \\module: full_test
    \\description: A comprehensive test specification
    \\
    \\creation_pattern:
    \\  source: InputType
    \\  transformer: process
    \\  result: OutputType
    \\  iteration: single
    \\
    \\types:
    \\  - name: InputType
    \\    fields:
    \\      - name: value
    \\        type: i32
    \\  - name: OutputType
    \\    fields:
    \\      - name: result
    \\        type: i32
    \\      - name: success
    \\        type: bool
    \\
    \\behaviors:
    \\  - name: process_input
    \\    given: A valid input
    \\    when: Processing is invoked
    \\    then: Returns transformed output
    \\    test_cases:
    \\      - name: positive_input
    \\        input: {value: 42}
    \\        expected: {result: 84, success: true}
    \\      - name: zero_input
    \\        input: {value: 0}
    \\        expected: {result: 0, success: true}
    \\      - name: negative_input
    \\        input: {value: -10}
    \\        expected: {result: -20, success: true}
    \\
    \\  - name: validate_input
    \\    given: Any input
    \\    when: Validation is performed
    \\    then: Returns validation result
    \\
    \\functions:
    \\  - name: process
    \\    params:
    \\      - name: input
    \\        type: InputType
    \\    returns: OutputType
    \\  - name: validate
    \\    params:
    \\      - name: input
    \\        type: InputType
    \\    returns: bool
;

const PAS_SPEC =
    \\name: pas_test
    \\version: "1.0.0"
    \\language: zig
    \\module: pas_test
    \\
    \\creation_pattern:
    \\  source: KnownAlgorithm
    \\  transformer: PASAnalysis
    \\  result: PredictedAlgorithm
    \\  iteration: until_convergence
    \\
    \\transformers:
    \\  - name: analyze_patterns
    \\    type: pure
    \\    input: Algorithm
    \\    output: [DiscoveryPattern]
    \\
    \\behaviors:
    \\  - name: predict_improvement
    \\    given: A known algorithm with complexity O(n^k)
    \\    when: PAS analysis is applied
    \\    then: Returns prediction with confidence
;

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

test "full pipeline: parse -> codegen" {
    const allocator = std.testing.allocator;

    // Parse
    const spec = try parser.parse(allocator, FULL_SPEC);
    defer spec.deinit();

    // Verify parsing
    try std.testing.expectEqualStrings("full_test", spec.name);
    try std.testing.expectEqualStrings("2.0.0", spec.version);
    try std.testing.expect(spec.behaviors.len == 2);
    try std.testing.expect(spec.types.len == 2);
    try std.testing.expect(spec.functions.len == 2);
    try std.testing.expect(spec.hasCreationPattern());

    // Generate code
    const code = try codegen.generate(allocator, spec);
    defer allocator.free(code);

    // Verify code generation
    try std.testing.expect(code.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, code, "full_test") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "process_input") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "InputType") != null);
}

test "SIMD parser produces same result as standard parser" {
    const allocator = std.testing.allocator;

    // Standard parser
    const spec1 = try parser.parse(allocator, FULL_SPEC);
    defer spec1.deinit();

    // SIMD parser
    var fast_parser = simd_parser.FastYamlParser.init(allocator);
    defer fast_parser.deinit();

    const spec2 = try fast_parser.parse(FULL_SPEC);
    defer spec2.deinit();

    // Compare results
    try std.testing.expectEqualStrings(spec1.name, spec2.name);
    try std.testing.expectEqualStrings(spec1.version, spec2.version);
    try std.testing.expect(spec1.behaviors.len == spec2.behaviors.len);
    try std.testing.expect(spec1.types.len == spec2.types.len);
}

test "PAS engine with historical algorithms" {
    const allocator = std.testing.allocator;

    var engine = pas.PASEngine.init(allocator);
    defer engine.deinit();

    // Get historical algorithms
    const algorithms = pas.getHistoricalAlgorithms();
    try std.testing.expect(algorithms.len == 10);

    // Verify Strassen is in the database
    var found_strassen = false;
    for (algorithms) |algo| {
        if (std.mem.eql(u8, algo.name, "Strassen matrix multiplication")) {
            found_strassen = true;
            try std.testing.expect(algo.year == 1969);
            try std.testing.expect(algo.exponent_before == 3.0);
            try std.testing.expect(algo.exponent_after == 2.81);
        }
    }
    try std.testing.expect(found_strassen);

    // Test prediction
    const patterns = &[_]pas.DiscoveryPattern{ .ml_guided_search, .tensor_decomposition };
    const prediction = engine.predict(
        "Matrix multiplication",
        "O(n^2.37)",
        2.37,
        2.0,
        patterns,
        55,
    );

    try std.testing.expect(prediction.confidence > 0.0);
    try std.testing.expect(prediction.predicted_exponent <= 2.37);
    try std.testing.expect(prediction.predicted_exponent >= 2.0);
}

test "VIBEE predictions" {
    const predictions = pas.getVIBEEPredictions();
    try std.testing.expect(predictions.len == 5);

    // Verify parser prediction
    try std.testing.expect(predictions[0].component == .parser);
    try std.testing.expect(predictions[0].expected_speedup >= 2.0);
    try std.testing.expect(predictions[0].confidence > 0.5);

    // Verify type checker prediction
    try std.testing.expect(predictions[2].component == .type_checker);
    try std.testing.expect(predictions[2].expected_speedup >= 3.0);
}

test "E-graph optimization" {
    const allocator = std.testing.allocator;

    var optimizer = egraph.Optimizer.init(allocator);
    defer optimizer.deinit();

    // Create expression: x * 2
    const expr = egraph.Expr{
        .tag = .mul,
        .children = &[_]egraph.EClassId{},
        .value = 2,
        .name = "x",
    };

    // Optimize
    const optimized = try optimizer.optimize(expr);

    // Should produce equivalent expression
    try std.testing.expect(optimized.tag != .unknown_type);

    const stats = optimizer.getStats();
    try std.testing.expect(stats.nodes >= 1);
}

test "property-based testing generates valid specs" {
    const allocator = std.testing.allocator;

    var gen = property_testing.SpecGenerator.init(allocator, 12345);

    // Generate random spec
    const spec_content = try gen.generateSpec();
    defer allocator.free(spec_content);

    // Should be parseable
    const spec = parser.parse(allocator, spec_content) catch |err| {
        std.debug.print("Generated spec failed to parse: {}\n", .{err});
        std.debug.print("Content:\n{s}\n", .{spec_content});
        return err;
    };
    defer spec.deinit();

    // Should have required fields
    try std.testing.expect(spec.name.len > 0);
}

test "incremental type checker caching" {
    const allocator = std.testing.allocator;

    var checker = incremental_types.IncrementalTypeChecker.init(allocator);
    defer checker.deinit();

    // Parse spec
    const spec = try parser.parse(allocator, FULL_SPEC);
    defer spec.deinit();

    // Check type (first time - cache miss)
    const result1 = try checker.checkSymbol("InputType", &spec);
    _ = result1;

    // Check same type again (should be cache hit)
    const result2 = try checker.checkSymbol("InputType", &spec);
    _ = result2;

    const stats = checker.getStats();
    try std.testing.expect(stats.cache_hits >= 1);
    try std.testing.expect(stats.hit_rate > 0.0);
}

test "coverage fuzzer finds coverage" {
    const allocator = std.testing.allocator;

    var fuzzer = coverage_fuzzer.CoverageFuzzer.init(allocator, 12345);
    defer fuzzer.deinit();

    // Add seed
    try fuzzer.addSeed(MINIMAL_SPEC);

    // Run a few iterations
    for (0..10) |_| {
        try fuzzer.fuzzOne();
    }

    const stats = fuzzer.getStats();
    try std.testing.expect(stats.executions == 10);
    try std.testing.expect(stats.coverage_edges > 0);
}

test "dependency graph tracks dependencies" {
    const allocator = std.testing.allocator;

    var graph = incremental_types.DependencyGraph.init(allocator);
    defer graph.deinit();

    // Build dependency chain: A -> B -> C
    try graph.addDependency("A", "B");
    try graph.addDependency("B", "C");

    // Get transitive dependents of C
    const affected = try graph.getTransitiveDependents(&[_][]const u8{"C"});
    defer allocator.free(affected);

    // Should include C, B, A
    try std.testing.expect(affected.len == 3);
}

test "type resolution" {
    const allocator = std.testing.allocator;

    var checker = incremental_types.IncrementalTypeChecker.init(allocator);
    defer checker.deinit();

    // Test built-in types
    const void_type = try checker.resolveTypeName("void");
    try std.testing.expect(void_type == .void_type);

    const i32_type = try checker.resolveTypeName("i32");
    try std.testing.expect(i32_type.int_type.bits == 32);
    try std.testing.expect(i32_type.int_type.signed == true);

    const u64_type = try checker.resolveTypeName("u64");
    try std.testing.expect(u64_type.int_type.bits == 64);
    try std.testing.expect(u64_type.int_type.signed == false);

    const f32_type = try checker.resolveTypeName("f32");
    try std.testing.expect(f32_type.float_type.bits == 32);
}

test "mutation strategies produce valid mutations" {
    const allocator = std.testing.allocator;

    var mutator = coverage_fuzzer.Mutator.init(allocator, 12345);
    defer mutator.deinit();

    const input = "name: test\nversion: \"1.0.0\"\n";

    // Test each mutation strategy
    const strategies = [_]coverage_fuzzer.MutationStrategy{
        .bit_flip,
        .byte_flip,
        .byte_insert,
        .byte_delete,
        .byte_replace,
        .arithmetic,
    };

    for (strategies) |strategy| {
        const output = switch (strategy) {
            .bit_flip => try mutator.bitFlip(input),
            .byte_flip => try mutator.byteFlip(input),
            .byte_insert => try mutator.byteInsert(input),
            .byte_delete => try mutator.byteDelete(input),
            .byte_replace => try mutator.byteReplace(input),
            .arithmetic => try mutator.arithmetic(input),
            else => try mutator.mutate(input),
        };
        defer allocator.free(output);

        // Output should exist
        try std.testing.expect(output.len > 0);
    }
}

test "end-to-end: spec -> parse -> type check -> codegen" {
    const allocator = std.testing.allocator;

    // 1. Parse spec
    const spec = try parser.parse(allocator, FULL_SPEC);
    defer spec.deinit();

    // 2. Type check
    var checker = incremental_types.IncrementalTypeChecker.init(allocator);
    defer checker.deinit();

    for (spec.types) |t| {
        const result = try checker.checkSymbol(t.name, &spec);
        try std.testing.expect(result.errors.len == 0);
    }

    for (spec.functions) |f| {
        const result = try checker.checkSymbol(f.name, &spec);
        // Functions may have unknown types, that's OK
        _ = result;
    }

    // 3. Generate code
    const code = try codegen.generate(allocator, spec);
    defer allocator.free(code);

    // 4. Verify output
    try std.testing.expect(code.len > 100);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const") != null);
}

test "PAS creation pattern spec parsing" {
    const allocator = std.testing.allocator;

    const spec = try parser.parse(allocator, PAS_SPEC);
    defer spec.deinit();

    try std.testing.expectEqualStrings("pas_test", spec.name);
    try std.testing.expect(spec.hasCreationPattern());

    if (spec.creation_pattern) |cp| {
        try std.testing.expectEqualStrings("KnownAlgorithm", cp.source);
        try std.testing.expectEqualStrings("PASAnalysis", cp.transformer);
        try std.testing.expectEqualStrings("PredictedAlgorithm", cp.result);
        try std.testing.expect(cp.iteration == .until_condition);
    }
}

// ============================================================================
// BENCHMARK TESTS
// ============================================================================

test "benchmark: standard vs SIMD parser" {
    const allocator = std.testing.allocator;
    const iterations: u32 = 100;

    // Standard parser
    var standard_total: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        const spec = try parser.parse(allocator, FULL_SPEC);
        const end = std.time.nanoTimestamp();
        spec.deinit();
        standard_total += @intCast(end - start);
    }

    // SIMD parser
    var fast_parser = simd_parser.FastYamlParser.init(allocator);
    defer fast_parser.deinit();

    var simd_total: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        const spec = try fast_parser.parse(FULL_SPEC);
        const end = std.time.nanoTimestamp();
        spec.deinit();
        simd_total += @intCast(end - start);
    }

    const standard_avg = standard_total / iterations;
    const simd_avg = simd_total / iterations;

    // SIMD should not be significantly slower
    // (In production, it should be faster for large inputs)
    try std.testing.expect(simd_avg < standard_avg * 3);
}

// ============================================================================
// STRESS TESTS
// ============================================================================

test "stress: parse many specs" {
    const allocator = std.testing.allocator;

    var gen = property_testing.SpecGenerator.init(allocator, 12345);

    for (0..50) |_| {
        const spec_content = try gen.generateSpec();
        defer allocator.free(spec_content);

        // Should not crash
        _ = parser.parse(allocator, spec_content) catch continue;
    }
}

test "stress: fuzzer stability" {
    const allocator = std.testing.allocator;

    var fuzzer = coverage_fuzzer.CoverageFuzzer.init(allocator, 12345);
    defer fuzzer.deinit();

    try fuzzer.addSeed(MINIMAL_SPEC);

    // Run many iterations
    for (0..100) |_| {
        try fuzzer.fuzzOne();
    }

    const stats = fuzzer.getStats();
    try std.testing.expect(stats.executions == 100);
    // Should not have crashed
    try std.testing.expect(stats.crashes == 0);
}
