// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FEW-SHOT EXAMPLES - Training examples for LLM agent
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

pub const EXAMPLE_1_NAVIGATE =
    \\GOAL: Go to example.com
    \\URL: about:blank
    \\Title: 
    \\ACTION: navigate https://example.com
;

pub const EXAMPLE_2_CLICK_LINK =
    \\GOAL: Click the "More information" link on example.com
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: click a
;

pub const EXAMPLE_3_SEARCH =
    \\GOAL: Search for "weather" on Google
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: click textarea[name=q]
    \\---
    \\GOAL: Search for "weather" on Google
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: type weather
    \\---
    \\GOAL: Search for "weather" on Google
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: enter
;

pub const EXAMPLE_4_REPORT_TITLE =
    \\GOAL: Tell me the title of example.com
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: done The title is "Example Domain"
;

pub const EXAMPLE_5_SCROLL =
    \\GOAL: Scroll down on the page
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: scroll down
;

pub const EXAMPLE_6_FORM =
    \\GOAL: Fill in the search box with "hello"
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: click input[name=q]
    \\---
    \\GOAL: Fill in the search box with "hello"
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: type hello
;

pub const EXAMPLE_7_DONE =
    \\GOAL: Navigate to example.com and report what you see
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: done I see Example Domain page with a heading and a link to more information
;

// Combined few-shot prompt
pub const FEW_SHOT_PROMPT =
    \\You are a browser automation agent. You can perform these actions:
    \\- navigate URL (go to a webpage)
    \\- click SELECTOR (click an element by CSS selector)
    \\- type TEXT (type text into focused element)
    \\- enter (press Enter key)
    \\- scroll down/up (scroll the page)
    \\- done RESULT (task complete, report result)
    \\
    \\Reply with ONLY the action, nothing else.
    \\
    \\EXAMPLES:
    \\
    \\GOAL: Go to example.com
    \\URL: about:blank
    \\Title: 
    \\ACTION: navigate https://example.com
    \\
    \\GOAL: Click the link on example.com
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: click a
    \\
    \\GOAL: Search for "test" on Google
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: type test
    \\
    \\GOAL: Submit the search
    \\URL: https://www.google.com/
    \\Title: Google
    \\ACTION: enter
    \\
    \\GOAL: Tell me the page title
    \\URL: https://example.com/
    \\Title: Example Domain
    \\ACTION: done The title is "Example Domain"
    \\
    \\NOW YOUR TURN:
;

// Compact few-shot for smaller context - FIXED v23.6
pub const FEW_SHOT_COMPACT =
    \\Browser bot. Output ONLY the command, nothing else.
    \\
    \\WRONG: "navigate URL" or "I will click"
    \\CORRECT: "navigate https://example.com" or "click a"
    \\
    \\Commands:
    \\navigate https://URL - go to website
    \\click SELECTOR - click element (a, button, #id, .class)
    \\type TEXT - type text
    \\enter - press enter
    \\done RESULT - task complete, report result
    \\
    \\Examples:
    \\GOAL: Go to google.com → navigate https://google.com
    \\GOAL: Click the link → click a
    \\GOAL: Search for cats → type cats
    \\GOAL: Submit → enter
    \\GOAL: What is the title? Title: Example → done The title is Example
    \\
    \\OUTPUT:
;

// Optimized prompt with DOM awareness (v23.3)
pub const FEW_SHOT_DOM_AWARE =
    \\Browser agent. Use DOM elements to find correct selectors.
    \\
    \\Actions: navigate URL | click SEL | type TXT | enter | scroll down | select SEL:VAL | check SEL:true/false | done RESULT
    \\
    \\DOM format: tag#id.class name=X href=Y "text"
    \\Use: #id, .class, tag, or [name=X] as selectors
    \\
    \\Examples:
    \\DOM: button#submit.btn "Submit" → click #submit
    \\DOM: input.search name=q → click .search then type query
    \\DOM: a href=/login "Login" → click a
    \\DOM: select#country → select #country:USA
    \\DOM: input#agree type=checkbox → check #agree:true
    \\
    \\Strategy:
    \\1. If goal is navigation → navigate URL
    \\2. If need to interact → find element in DOM, use best selector
    \\3. If goal achieved → done with result
    \\4. Prefer #id > .class > tag selectors
    \\
    \\YOUR TURN:
;

// Ultra-compact for fast inference
pub const FEW_SHOT_ULTRA =
    \\Agent: navigate|click|type|enter|scroll|select|check|done
    \\DOM: tag#id.class "text" → use #id or .class
    \\Ex: button#go "Go" → click #go
    \\Ex: input.q → type query
    \\Ex: select#lang → select #lang:en
    \\GO:
;

test "few shot prompts exist" {
    const std = @import("std");
    try std.testing.expect(FEW_SHOT_PROMPT.len > 0);
    try std.testing.expect(FEW_SHOT_COMPACT.len > 0);
    try std.testing.expect(FEW_SHOT_DOM_AWARE.len > 0);
    try std.testing.expect(FEW_SHOT_ULTRA.len > 0);
}

test "phi constant" {
    const std = @import("std");
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
