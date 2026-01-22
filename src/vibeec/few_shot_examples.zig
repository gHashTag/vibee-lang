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

// Compact few-shot for smaller context
pub const FEW_SHOT_COMPACT =
    \\Browser agent. Actions: navigate URL | click SEL | type TXT | enter | scroll down | done RESULT
    \\
    \\Ex1: GOAL:Go to example.com URL:blank → navigate https://example.com
    \\Ex2: GOAL:Click link URL:example.com Title:Example Domain → click a
    \\Ex3: GOAL:Type hello URL:google.com → type hello
    \\Ex4: GOAL:Submit URL:google.com → enter
    \\Ex5: GOAL:Report title URL:example.com Title:Example Domain → done Title is Example Domain
    \\
    \\YOUR TURN:
;
