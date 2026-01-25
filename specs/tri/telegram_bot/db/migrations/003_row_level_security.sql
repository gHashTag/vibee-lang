-- ═══════════════════════════════════════════════════════════════
-- VIBEE Telegram Bot - Row Level Security (RLS)
-- Supabase security policies
-- ═══════════════════════════════════════════════════════════════

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompts_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE avatars ENABLE ROW LEVEL SECURITY;
ALTER TABLE bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE cryptobot_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_voices ENABLE ROW LEVEL SECURITY;

-- Service role can do everything (for backend)
CREATE POLICY "Service role full access on users"
    ON users FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on payments_v2"
    ON payments_v2 FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on prompts_history"
    ON prompts_history FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on model_trainings"
    ON model_trainings FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on avatars"
    ON avatars FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on bots"
    ON bots FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on generation_queue"
    ON generation_queue FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on cryptobot_invoices"
    ON cryptobot_invoices FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on user_voices"
    ON user_voices FOR ALL
    USING (auth.role() = 'service_role');

-- Public tables (no RLS needed)
ALTER TABLE translations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access on translations"
    ON translations FOR SELECT
    USING (true);

ALTER TABLE service_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access on service_prices"
    ON service_prices FOR SELECT
    USING (true);

ALTER TABLE daily_balance_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access on daily_balance_stats"
    ON daily_balance_stats FOR ALL
    USING (auth.role() = 'service_role');

-- ═══════════════════════════════════════════════════════════════
-- GRANTS
-- ═══════════════════════════════════════════════════════════════

-- Grant usage on sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant all on tables to service_role
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
