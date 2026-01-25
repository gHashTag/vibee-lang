// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - coptic_ast v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module coptic_ast (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] TritValue_negative_in,
  output reg  [63:0] TritValue_negative_out,
  input  wire [63:0] TritValue_zero_in,
  output reg  [63:0] TritValue_zero_out,
  input  wire [63:0] TritValue_positive_in,
  output reg  [63:0] TritValue_positive_out,
  input  wire [63:0] TypeKind_trit_in,
  output reg  [63:0] TypeKind_trit_out,
  input  wire [63:0] TypeKind_tryte_in,
  output reg  [63:0] TypeKind_tryte_out,
  input  wire [63:0] TypeKind_trint_in,
  output reg  [63:0] TypeKind_trint_out,
  input  wire [63:0] TypeKind_trfloat_in,
  output reg  [63:0] TypeKind_trfloat_out,
  input  wire [63:0] TypeKind_phi_in,
  output reg  [63:0] TypeKind_phi_out,
  input  wire [63:0] TypeKind_pi_type_in,
  output reg  [63:0] TypeKind_pi_type_out,
  input  wire [63:0] TypeKind_tau_in,
  output reg  [63:0] TypeKind_tau_out,
  input  wire [63:0] TypeKind_euler_in,
  output reg  [63:0] TypeKind_euler_out,
  input  wire [63:0] TypeKind_pointer_in,
  output reg  [63:0] TypeKind_pointer_out,
  input  wire [63:0] TypeKind_array_in,
  output reg  [63:0] TypeKind_array_out,
  input  wire [63:0] TypeKind_slice_in,
  output reg  [63:0] TypeKind_slice_out,
  input  wire [63:0] TypeKind_optional_in,
  output reg  [63:0] TypeKind_optional_out,
  input  wire [63:0] TypeKind_struct_type_in,
  output reg  [63:0] TypeKind_struct_type_out,
  input  wire [63:0] TypeKind_union_type_in,
  output reg  [63:0] TypeKind_union_type_out,
  input  wire [63:0] TypeKind_func_type_in,
  output reg  [63:0] TypeKind_func_type_out,
  input  wire [63:0] TypeKind_void_type_in,
  output reg  [63:0] TypeKind_void_type_out,
  input  wire [63:0] TypeKind_custom_in,
  output reg  [63:0] TypeKind_custom_out,
  input  wire [255:0] Type_kind_in,
  output reg  [255:0] Type_kind_out,
  input  wire [63:0] Type_name_in,
  output reg  [63:0] Type_name_out,
  input  wire [63:0] Type_inner_in,
  output reg  [63:0] Type_inner_out,
  input  wire [63:0] Type_array_size_in,
  output reg  [63:0] Type_array_size_out,
  input  wire [63:0] ExprKind_trit_literal_in,
  output reg  [63:0] ExprKind_trit_literal_out,
  input  wire [63:0] ExprKind_int_literal_in,
  output reg  [63:0] ExprKind_int_literal_out,
  input  wire [63:0] ExprKind_float_literal_in,
  output reg  [63:0] ExprKind_float_literal_out,
  input  wire [63:0] ExprKind_string_literal_in,
  output reg  [63:0] ExprKind_string_literal_out,
  input  wire [63:0] ExprKind_identifier_in,
  output reg  [63:0] ExprKind_identifier_out,
  input  wire [63:0] ExprKind_phi_const_in,
  output reg  [63:0] ExprKind_phi_const_out,
  input  wire [63:0] ExprKind_pi_const_in,
  output reg  [63:0] ExprKind_pi_const_out,
  input  wire [63:0] ExprKind_tau_const_in,
  output reg  [63:0] ExprKind_tau_const_out,
  input  wire [63:0] ExprKind_euler_const_in,
  output reg  [63:0] ExprKind_euler_const_out,
  input  wire [63:0] ExprKind_binary_op_in,
  output reg  [63:0] ExprKind_binary_op_out,
  input  wire [63:0] ExprKind_unary_op_in,
  output reg  [63:0] ExprKind_unary_op_out,
  input  wire [63:0] ExprKind_call_in,
  output reg  [63:0] ExprKind_call_out,
  input  wire [63:0] ExprKind_field_access_in,
  output reg  [63:0] ExprKind_field_access_out,
  input  wire [63:0] ExprKind_index_in,
  output reg  [63:0] ExprKind_index_out,
  input  wire [63:0] ExprKind_grouping_in,
  output reg  [63:0] ExprKind_grouping_out,
  input  wire [63:0] ExprKind_block_in,
  output reg  [63:0] ExprKind_block_out,
  input  wire [63:0] ExprKind_if_expr_in,
  output reg  [63:0] ExprKind_if_expr_out,
  input  wire [63:0] ExprKind_match_expr_in,
  output reg  [63:0] ExprKind_match_expr_out,
  input  wire [63:0] BinaryOp_add_in,
  output reg  [63:0] BinaryOp_add_out,
  input  wire [63:0] BinaryOp_sub_in,
  output reg  [63:0] BinaryOp_sub_out,
  input  wire [63:0] BinaryOp_mul_in,
  output reg  [63:0] BinaryOp_mul_out,
  input  wire [63:0] BinaryOp_div_in,
  output reg  [63:0] BinaryOp_div_out,
  input  wire [63:0] BinaryOp_mod_in,
  output reg  [63:0] BinaryOp_mod_out,
  input  wire [63:0] BinaryOp_pow_in,
  output reg  [63:0] BinaryOp_pow_out,
  input  wire [63:0] BinaryOp_t_and_in,
  output reg  [63:0] BinaryOp_t_and_out,
  input  wire [63:0] BinaryOp_t_or_in,
  output reg  [63:0] BinaryOp_t_or_out,
  input  wire [63:0] BinaryOp_t_xor_in,
  output reg  [63:0] BinaryOp_t_xor_out,
  input  wire [63:0] BinaryOp_eq_in,
  output reg  [63:0] BinaryOp_eq_out,
  input  wire [63:0] BinaryOp_neq_in,
  output reg  [63:0] BinaryOp_neq_out,
  input  wire [63:0] BinaryOp_lt_in,
  output reg  [63:0] BinaryOp_lt_out,
  input  wire [63:0] BinaryOp_gt_in,
  output reg  [63:0] BinaryOp_gt_out,
  input  wire [63:0] BinaryOp_le_in,
  output reg  [63:0] BinaryOp_le_out,
  input  wire [63:0] BinaryOp_ge_in,
  output reg  [63:0] BinaryOp_ge_out,
  input  wire [63:0] UnaryOp_neg_in,
  output reg  [63:0] UnaryOp_neg_out,
  input  wire [63:0] UnaryOp_t_not_in,
  output reg  [63:0] UnaryOp_t_not_out,
  input  wire [63:0] UnaryOp_deref_in,
  output reg  [63:0] UnaryOp_deref_out,
  input  wire [63:0] UnaryOp_addr_of_in,
  output reg  [63:0] UnaryOp_addr_of_out,
  input  wire [255:0] Expr_kind_in,
  output reg  [255:0] Expr_kind_out,
  input  wire [63:0] Expr_line_in,
  output reg  [63:0] Expr_line_out,
  input  wire [63:0] Expr_column_in,
  output reg  [63:0] Expr_column_out,
  input  wire [255:0] Expr_data_in,
  output reg  [255:0] Expr_data_out,
  input  wire [255:0] BinaryExpr_left_in,
  output reg  [255:0] BinaryExpr_left_out,
  input  wire [255:0] BinaryExpr_op_in,
  output reg  [255:0] BinaryExpr_op_out,
  input  wire [255:0] BinaryExpr_right_in,
  output reg  [255:0] BinaryExpr_right_out,
  input  wire [255:0] UnaryExpr_op_in,
  output reg  [255:0] UnaryExpr_op_out,
  input  wire [255:0] UnaryExpr_operand_in,
  output reg  [255:0] UnaryExpr_operand_out,
  input  wire [255:0] CallExpr_callee_in,
  output reg  [255:0] CallExpr_callee_out,
  input  wire [511:0] CallExpr_args_in,
  output reg  [511:0] CallExpr_args_out,
  input  wire [255:0] MatchExpr_value_in,
  output reg  [255:0] MatchExpr_value_out,
  input  wire [255:0] MatchExpr_negative_branch_in,
  output reg  [255:0] MatchExpr_negative_branch_out,
  input  wire [255:0] MatchExpr_zero_branch_in,
  output reg  [255:0] MatchExpr_zero_branch_out,
  input  wire [255:0] MatchExpr_positive_branch_in,
  output reg  [255:0] MatchExpr_positive_branch_out,
  input  wire [63:0] StmtKind_module_decl_in,
  output reg  [63:0] StmtKind_module_decl_out,
  input  wire [63:0] StmtKind_const_decl_in,
  output reg  [63:0] StmtKind_const_decl_out,
  input  wire [63:0] StmtKind_var_decl_in,
  output reg  [63:0] StmtKind_var_decl_out,
  input  wire [63:0] StmtKind_func_decl_in,
  output reg  [63:0] StmtKind_func_decl_out,
  input  wire [63:0] StmtKind_struct_decl_in,
  output reg  [63:0] StmtKind_struct_decl_out,
  input  wire [63:0] StmtKind_return_stmt_in,
  output reg  [63:0] StmtKind_return_stmt_out,
  input  wire [63:0] StmtKind_loop_stmt_in,
  output reg  [63:0] StmtKind_loop_stmt_out,
  input  wire [63:0] StmtKind_if_stmt_in,
  output reg  [63:0] StmtKind_if_stmt_out,
  input  wire [63:0] StmtKind_match_stmt_in,
  output reg  [63:0] StmtKind_match_stmt_out,
  input  wire [63:0] StmtKind_defer_stmt_in,
  output reg  [63:0] StmtKind_defer_stmt_out,
  input  wire [63:0] StmtKind_expr_stmt_in,
  output reg  [63:0] StmtKind_expr_stmt_out,
  input  wire [63:0] StmtKind_comptime_block_in,
  output reg  [63:0] StmtKind_comptime_block_out,
  input  wire [255:0] Stmt_kind_in,
  output reg  [255:0] Stmt_kind_out,
  input  wire [63:0] Stmt_line_in,
  output reg  [63:0] Stmt_line_out,
  input  wire [63:0] Stmt_column_in,
  output reg  [63:0] Stmt_column_out,
  input  wire [255:0] Stmt_data_in,
  output reg  [255:0] Stmt_data_out,
  input  wire [255:0] ModuleDecl_name_in,
  output reg  [255:0] ModuleDecl_name_out,
  input  wire [255:0] VarDecl_name_in,
  output reg  [255:0] VarDecl_name_out,
  input  wire [63:0] VarDecl_type_annotation_in,
  output reg  [63:0] VarDecl_type_annotation_out,
  input  wire [63:0] VarDecl_initializer_in,
  output reg  [63:0] VarDecl_initializer_out,
  input  wire  VarDecl_is_comptime_in,
  output reg   VarDecl_is_comptime_out,
  input  wire [255:0] FuncDecl_name_in,
  output reg  [255:0] FuncDecl_name_out,
  input  wire [511:0] FuncDecl_params_in,
  output reg  [511:0] FuncDecl_params_out,
  input  wire [255:0] FuncDecl_return_type_in,
  output reg  [255:0] FuncDecl_return_type_out,
  input  wire [511:0] FuncDecl_body_in,
  output reg  [511:0] FuncDecl_body_out,
  input  wire  FuncDecl_is_comptime_in,
  output reg   FuncDecl_is_comptime_out,
  input  wire [255:0] Param_name_in,
  output reg  [255:0] Param_name_out,
  input  wire [255:0] Param_param_type_in,
  output reg  [255:0] Param_param_type_out,
  input  wire  Param_is_comptime_in,
  output reg   Param_is_comptime_out,
  input  wire [255:0] StructDecl_name_in,
  output reg  [255:0] StructDecl_name_out,
  input  wire [511:0] StructDecl_fields_in,
  output reg  [511:0] StructDecl_fields_out,
  input  wire [255:0] Field_name_in,
  output reg  [255:0] Field_name_out,
  input  wire [255:0] Field_field_type_in,
  output reg  [255:0] Field_field_type_out,
  input  wire [63:0] Field_default_value_in,
  output reg  [63:0] Field_default_value_out,
  input  wire [255:0] LoopStmt_condition_in,
  output reg  [255:0] LoopStmt_condition_out,
  input  wire [511:0] LoopStmt_body_in,
  output reg  [511:0] LoopStmt_body_out,
  input  wire [255:0] IfStmt_condition_in,
  output reg  [255:0] IfStmt_condition_out,
  input  wire [511:0] IfStmt_then_branch_in,
  output reg  [511:0] IfStmt_then_branch_out,
  input  wire [63:0] IfStmt_else_branch_in,
  output reg  [63:0] IfStmt_else_branch_out,
  input  wire [255:0] MatchStmt_value_in,
  output reg  [255:0] MatchStmt_value_out,
  input  wire [511:0] MatchStmt_negative_branch_in,
  output reg  [511:0] MatchStmt_negative_branch_out,
  input  wire [511:0] MatchStmt_zero_branch_in,
  output reg  [511:0] MatchStmt_zero_branch_out,
  input  wire [511:0] MatchStmt_positive_branch_in,
  output reg  [511:0] MatchStmt_positive_branch_out,
  input  wire [63:0] Program_module_name_in,
  output reg  [63:0] Program_module_name_out,
  input  wire [511:0] Program_statements_in,
  output reg  [511:0] Program_statements_out,
  input  wire [255:0] AstBuilder_allocator_in,
  output reg  [255:0] AstBuilder_allocator_out,
  output reg         done
);

  // Sacred constants (φ² + 1/φ² = 3)
  localparam [31:0] PHI = 32'd1618033;      // φ × 10^6
  localparam [31:0] PHI_INV = 32'd618033;   // 1/φ × 10^6
  localparam [31:0] TRINITY = 32'd3;        // φ² + 1/φ² = 3
  localparam [31:0] PHOENIX = 32'd999;      // Sacred number

  // State machine
  localparam IDLE = 2'b00, PROCESS = 2'b01, DONE = 2'b10;
  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      TritValue_negative_out <= 64'd0;
      TritValue_zero_out <= 64'd0;
      TritValue_positive_out <= 64'd0;
      TypeKind_trit_out <= 64'd0;
      TypeKind_tryte_out <= 64'd0;
      TypeKind_trint_out <= 64'd0;
      TypeKind_trfloat_out <= 64'd0;
      TypeKind_phi_out <= 64'd0;
      TypeKind_pi_type_out <= 64'd0;
      TypeKind_tau_out <= 64'd0;
      TypeKind_euler_out <= 64'd0;
      TypeKind_pointer_out <= 64'd0;
      TypeKind_array_out <= 64'd0;
      TypeKind_slice_out <= 64'd0;
      TypeKind_optional_out <= 64'd0;
      TypeKind_struct_type_out <= 64'd0;
      TypeKind_union_type_out <= 64'd0;
      TypeKind_func_type_out <= 64'd0;
      TypeKind_void_type_out <= 64'd0;
      TypeKind_custom_out <= 64'd0;
      Type_kind_out <= 256'd0;
      Type_name_out <= 64'd0;
      Type_inner_out <= 64'd0;
      Type_array_size_out <= 64'd0;
      ExprKind_trit_literal_out <= 64'd0;
      ExprKind_int_literal_out <= 64'd0;
      ExprKind_float_literal_out <= 64'd0;
      ExprKind_string_literal_out <= 64'd0;
      ExprKind_identifier_out <= 64'd0;
      ExprKind_phi_const_out <= 64'd0;
      ExprKind_pi_const_out <= 64'd0;
      ExprKind_tau_const_out <= 64'd0;
      ExprKind_euler_const_out <= 64'd0;
      ExprKind_binary_op_out <= 64'd0;
      ExprKind_unary_op_out <= 64'd0;
      ExprKind_call_out <= 64'd0;
      ExprKind_field_access_out <= 64'd0;
      ExprKind_index_out <= 64'd0;
      ExprKind_grouping_out <= 64'd0;
      ExprKind_block_out <= 64'd0;
      ExprKind_if_expr_out <= 64'd0;
      ExprKind_match_expr_out <= 64'd0;
      BinaryOp_add_out <= 64'd0;
      BinaryOp_sub_out <= 64'd0;
      BinaryOp_mul_out <= 64'd0;
      BinaryOp_div_out <= 64'd0;
      BinaryOp_mod_out <= 64'd0;
      BinaryOp_pow_out <= 64'd0;
      BinaryOp_t_and_out <= 64'd0;
      BinaryOp_t_or_out <= 64'd0;
      BinaryOp_t_xor_out <= 64'd0;
      BinaryOp_eq_out <= 64'd0;
      BinaryOp_neq_out <= 64'd0;
      BinaryOp_lt_out <= 64'd0;
      BinaryOp_gt_out <= 64'd0;
      BinaryOp_le_out <= 64'd0;
      BinaryOp_ge_out <= 64'd0;
      UnaryOp_neg_out <= 64'd0;
      UnaryOp_t_not_out <= 64'd0;
      UnaryOp_deref_out <= 64'd0;
      UnaryOp_addr_of_out <= 64'd0;
      Expr_kind_out <= 256'd0;
      Expr_line_out <= 64'd0;
      Expr_column_out <= 64'd0;
      Expr_data_out <= 256'd0;
      BinaryExpr_left_out <= 256'd0;
      BinaryExpr_op_out <= 256'd0;
      BinaryExpr_right_out <= 256'd0;
      UnaryExpr_op_out <= 256'd0;
      UnaryExpr_operand_out <= 256'd0;
      CallExpr_callee_out <= 256'd0;
      CallExpr_args_out <= 512'd0;
      MatchExpr_value_out <= 256'd0;
      MatchExpr_negative_branch_out <= 256'd0;
      MatchExpr_zero_branch_out <= 256'd0;
      MatchExpr_positive_branch_out <= 256'd0;
      StmtKind_module_decl_out <= 64'd0;
      StmtKind_const_decl_out <= 64'd0;
      StmtKind_var_decl_out <= 64'd0;
      StmtKind_func_decl_out <= 64'd0;
      StmtKind_struct_decl_out <= 64'd0;
      StmtKind_return_stmt_out <= 64'd0;
      StmtKind_loop_stmt_out <= 64'd0;
      StmtKind_if_stmt_out <= 64'd0;
      StmtKind_match_stmt_out <= 64'd0;
      StmtKind_defer_stmt_out <= 64'd0;
      StmtKind_expr_stmt_out <= 64'd0;
      StmtKind_comptime_block_out <= 64'd0;
      Stmt_kind_out <= 256'd0;
      Stmt_line_out <= 64'd0;
      Stmt_column_out <= 64'd0;
      Stmt_data_out <= 256'd0;
      ModuleDecl_name_out <= 256'd0;
      VarDecl_name_out <= 256'd0;
      VarDecl_type_annotation_out <= 64'd0;
      VarDecl_initializer_out <= 64'd0;
      VarDecl_is_comptime_out <= 1'b0;
      FuncDecl_name_out <= 256'd0;
      FuncDecl_params_out <= 512'd0;
      FuncDecl_return_type_out <= 256'd0;
      FuncDecl_body_out <= 512'd0;
      FuncDecl_is_comptime_out <= 1'b0;
      Param_name_out <= 256'd0;
      Param_param_type_out <= 256'd0;
      Param_is_comptime_out <= 1'b0;
      StructDecl_name_out <= 256'd0;
      StructDecl_fields_out <= 512'd0;
      Field_name_out <= 256'd0;
      Field_field_type_out <= 256'd0;
      Field_default_value_out <= 64'd0;
      LoopStmt_condition_out <= 256'd0;
      LoopStmt_body_out <= 512'd0;
      IfStmt_condition_out <= 256'd0;
      IfStmt_then_branch_out <= 512'd0;
      IfStmt_else_branch_out <= 64'd0;
      MatchStmt_value_out <= 256'd0;
      MatchStmt_negative_branch_out <= 512'd0;
      MatchStmt_zero_branch_out <= 512'd0;
      MatchStmt_positive_branch_out <= 512'd0;
      Program_module_name_out <= 64'd0;
      Program_statements_out <= 512'd0;
      AstBuilder_allocator_out <= 256'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          TritValue_negative_out <= TritValue_negative_in;
          TritValue_zero_out <= TritValue_zero_in;
          TritValue_positive_out <= TritValue_positive_in;
          TypeKind_trit_out <= TypeKind_trit_in;
          TypeKind_tryte_out <= TypeKind_tryte_in;
          TypeKind_trint_out <= TypeKind_trint_in;
          TypeKind_trfloat_out <= TypeKind_trfloat_in;
          TypeKind_phi_out <= TypeKind_phi_in;
          TypeKind_pi_type_out <= TypeKind_pi_type_in;
          TypeKind_tau_out <= TypeKind_tau_in;
          TypeKind_euler_out <= TypeKind_euler_in;
          TypeKind_pointer_out <= TypeKind_pointer_in;
          TypeKind_array_out <= TypeKind_array_in;
          TypeKind_slice_out <= TypeKind_slice_in;
          TypeKind_optional_out <= TypeKind_optional_in;
          TypeKind_struct_type_out <= TypeKind_struct_type_in;
          TypeKind_union_type_out <= TypeKind_union_type_in;
          TypeKind_func_type_out <= TypeKind_func_type_in;
          TypeKind_void_type_out <= TypeKind_void_type_in;
          TypeKind_custom_out <= TypeKind_custom_in;
          Type_kind_out <= Type_kind_in;
          Type_name_out <= Type_name_in;
          Type_inner_out <= Type_inner_in;
          Type_array_size_out <= Type_array_size_in;
          ExprKind_trit_literal_out <= ExprKind_trit_literal_in;
          ExprKind_int_literal_out <= ExprKind_int_literal_in;
          ExprKind_float_literal_out <= ExprKind_float_literal_in;
          ExprKind_string_literal_out <= ExprKind_string_literal_in;
          ExprKind_identifier_out <= ExprKind_identifier_in;
          ExprKind_phi_const_out <= ExprKind_phi_const_in;
          ExprKind_pi_const_out <= ExprKind_pi_const_in;
          ExprKind_tau_const_out <= ExprKind_tau_const_in;
          ExprKind_euler_const_out <= ExprKind_euler_const_in;
          ExprKind_binary_op_out <= ExprKind_binary_op_in;
          ExprKind_unary_op_out <= ExprKind_unary_op_in;
          ExprKind_call_out <= ExprKind_call_in;
          ExprKind_field_access_out <= ExprKind_field_access_in;
          ExprKind_index_out <= ExprKind_index_in;
          ExprKind_grouping_out <= ExprKind_grouping_in;
          ExprKind_block_out <= ExprKind_block_in;
          ExprKind_if_expr_out <= ExprKind_if_expr_in;
          ExprKind_match_expr_out <= ExprKind_match_expr_in;
          BinaryOp_add_out <= BinaryOp_add_in;
          BinaryOp_sub_out <= BinaryOp_sub_in;
          BinaryOp_mul_out <= BinaryOp_mul_in;
          BinaryOp_div_out <= BinaryOp_div_in;
          BinaryOp_mod_out <= BinaryOp_mod_in;
          BinaryOp_pow_out <= BinaryOp_pow_in;
          BinaryOp_t_and_out <= BinaryOp_t_and_in;
          BinaryOp_t_or_out <= BinaryOp_t_or_in;
          BinaryOp_t_xor_out <= BinaryOp_t_xor_in;
          BinaryOp_eq_out <= BinaryOp_eq_in;
          BinaryOp_neq_out <= BinaryOp_neq_in;
          BinaryOp_lt_out <= BinaryOp_lt_in;
          BinaryOp_gt_out <= BinaryOp_gt_in;
          BinaryOp_le_out <= BinaryOp_le_in;
          BinaryOp_ge_out <= BinaryOp_ge_in;
          UnaryOp_neg_out <= UnaryOp_neg_in;
          UnaryOp_t_not_out <= UnaryOp_t_not_in;
          UnaryOp_deref_out <= UnaryOp_deref_in;
          UnaryOp_addr_of_out <= UnaryOp_addr_of_in;
          Expr_kind_out <= Expr_kind_in;
          Expr_line_out <= Expr_line_in;
          Expr_column_out <= Expr_column_in;
          Expr_data_out <= Expr_data_in;
          BinaryExpr_left_out <= BinaryExpr_left_in;
          BinaryExpr_op_out <= BinaryExpr_op_in;
          BinaryExpr_right_out <= BinaryExpr_right_in;
          UnaryExpr_op_out <= UnaryExpr_op_in;
          UnaryExpr_operand_out <= UnaryExpr_operand_in;
          CallExpr_callee_out <= CallExpr_callee_in;
          CallExpr_args_out <= CallExpr_args_in;
          MatchExpr_value_out <= MatchExpr_value_in;
          MatchExpr_negative_branch_out <= MatchExpr_negative_branch_in;
          MatchExpr_zero_branch_out <= MatchExpr_zero_branch_in;
          MatchExpr_positive_branch_out <= MatchExpr_positive_branch_in;
          StmtKind_module_decl_out <= StmtKind_module_decl_in;
          StmtKind_const_decl_out <= StmtKind_const_decl_in;
          StmtKind_var_decl_out <= StmtKind_var_decl_in;
          StmtKind_func_decl_out <= StmtKind_func_decl_in;
          StmtKind_struct_decl_out <= StmtKind_struct_decl_in;
          StmtKind_return_stmt_out <= StmtKind_return_stmt_in;
          StmtKind_loop_stmt_out <= StmtKind_loop_stmt_in;
          StmtKind_if_stmt_out <= StmtKind_if_stmt_in;
          StmtKind_match_stmt_out <= StmtKind_match_stmt_in;
          StmtKind_defer_stmt_out <= StmtKind_defer_stmt_in;
          StmtKind_expr_stmt_out <= StmtKind_expr_stmt_in;
          StmtKind_comptime_block_out <= StmtKind_comptime_block_in;
          Stmt_kind_out <= Stmt_kind_in;
          Stmt_line_out <= Stmt_line_in;
          Stmt_column_out <= Stmt_column_in;
          Stmt_data_out <= Stmt_data_in;
          ModuleDecl_name_out <= ModuleDecl_name_in;
          VarDecl_name_out <= VarDecl_name_in;
          VarDecl_type_annotation_out <= VarDecl_type_annotation_in;
          VarDecl_initializer_out <= VarDecl_initializer_in;
          VarDecl_is_comptime_out <= VarDecl_is_comptime_in;
          FuncDecl_name_out <= FuncDecl_name_in;
          FuncDecl_params_out <= FuncDecl_params_in;
          FuncDecl_return_type_out <= FuncDecl_return_type_in;
          FuncDecl_body_out <= FuncDecl_body_in;
          FuncDecl_is_comptime_out <= FuncDecl_is_comptime_in;
          Param_name_out <= Param_name_in;
          Param_param_type_out <= Param_param_type_in;
          Param_is_comptime_out <= Param_is_comptime_in;
          StructDecl_name_out <= StructDecl_name_in;
          StructDecl_fields_out <= StructDecl_fields_in;
          Field_name_out <= Field_name_in;
          Field_field_type_out <= Field_field_type_in;
          Field_default_value_out <= Field_default_value_in;
          LoopStmt_condition_out <= LoopStmt_condition_in;
          LoopStmt_body_out <= LoopStmt_body_in;
          IfStmt_condition_out <= IfStmt_condition_in;
          IfStmt_then_branch_out <= IfStmt_then_branch_in;
          IfStmt_else_branch_out <= IfStmt_else_branch_in;
          MatchStmt_value_out <= MatchStmt_value_in;
          MatchStmt_negative_branch_out <= MatchStmt_negative_branch_in;
          MatchStmt_zero_branch_out <= MatchStmt_zero_branch_in;
          MatchStmt_positive_branch_out <= MatchStmt_positive_branch_in;
          Program_module_name_out <= Program_module_name_in;
          Program_statements_out <= Program_statements_in;
          AstBuilder_allocator_out <= AstBuilder_allocator_in;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Behaviors:
  // - create_trit_literal
  // - test_negative
  // - test_zero
  // - test_positive
  // - create_binary_op
  // - test_add
  // - create_match_expr
  // - test_match
  // - trit_from_char
  // - test_alfa
  // - test_o
  // - test_omega
  // - trit_to_char
  // - test_neg_to_char
  // - golden_identity_check
  // - test_identity

endmodule
