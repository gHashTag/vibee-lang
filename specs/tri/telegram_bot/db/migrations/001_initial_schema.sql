-- ═══════════════════════════════════════════════════════════════
-- VIBEE Telegram Bot - Initial Database Schema
-- Generated from supabase_schema.vibee
-- ═══════════════════════════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════
-- USERS TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    language_code VARCHAR(10) DEFAULT 'ru',
    balance INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    is_premium BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    referral_code VARCHAR(50) UNIQUE,
    referred_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_telegram_id ON users(telegram_id);
CREATE INDEX idx_users_referral_code ON users(referral_code);

-- ═══════════════════════════════════════════════════════════════
-- PAYMENTS TABLE (v2)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS payments_v2 (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    amount_stars INTEGER NOT NULL,
    amount_usd DECIMAL(10, 4),
    amount_rubles DECIMAL(10, 2),
    payment_method VARCHAR(50) NOT NULL, -- stars, robokassa, cryptobot
    payment_type VARCHAR(50) NOT NULL,   -- top_up, service_payment
    service VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed, refunded
    external_id VARCHAR(255),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT fk_payments_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_payments_telegram_id ON payments_v2(telegram_id);
CREATE INDEX idx_payments_status ON payments_v2(status);
CREATE INDEX idx_payments_created_at ON payments_v2(created_at);

-- ═══════════════════════════════════════════════════════════════
-- PROMPTS HISTORY TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS prompts_history (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT NOT NULL,
    prompt TEXT NOT NULL,
    model VARCHAR(255) NOT NULL,
    result_url TEXT,
    cost_stars INTEGER NOT NULL,
    service VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_prompts_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_prompts_telegram_id ON prompts_history(telegram_id);
CREATE INDEX idx_prompts_created_at ON prompts_history(created_at);
CREATE INDEX idx_prompts_service ON prompts_history(service);

-- ═══════════════════════════════════════════════════════════════
-- MODEL TRAININGS TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS model_trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    trigger_word VARCHAR(100) NOT NULL,
    zip_url TEXT NOT NULL,
    steps INTEGER DEFAULT 1000,
    status VARCHAR(20) DEFAULT 'starting', -- starting, processing, succeeded, failed
    gender VARCHAR(20),
    api VARCHAR(50) DEFAULT 'replicate', -- replicate, fal
    bot_name VARCHAR(100),
    model_url TEXT,
    replicate_training_id VARCHAR(255),
    replicate_model_id VARCHAR(255),
    version_id VARCHAR(255),
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT fk_trainings_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_trainings_telegram_id ON model_trainings(telegram_id);
CREATE INDEX idx_trainings_status ON model_trainings(status);

-- ═══════════════════════════════════════════════════════════════
-- AVATARS TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS avatars (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    model_url TEXT NOT NULL,
    trigger_word VARCHAR(100) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    voice_id VARCHAR(255),
    is_active BOOLEAN DEFAULT FALSE,
    preview_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_avatars_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_avatars_telegram_id ON avatars(telegram_id);

-- ═══════════════════════════════════════════════════════════════
-- BOTS TABLE (Multibot)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bot_name VARCHAR(255) UNIQUE NOT NULL,
    bot_token TEXT NOT NULL, -- Should be encrypted
    owner_telegram_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_bots_owner FOREIGN KEY (owner_telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_bots_owner ON bots(owner_telegram_id);

-- ═══════════════════════════════════════════════════════════════
-- TRANSLATIONS TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS translations (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    language VARCHAR(10) NOT NULL,
    value TEXT NOT NULL,
    category VARCHAR(100),
    
    UNIQUE(key, language)
);

CREATE INDEX idx_translations_key ON translations(key);
CREATE INDEX idx_translations_language ON translations(language);

-- ═══════════════════════════════════════════════════════════════
-- DAILY BALANCE STATS TABLE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS daily_balance_stats (
    id SERIAL PRIMARY KEY,
    date DATE UNIQUE NOT NULL,
    total_users INTEGER DEFAULT 0,
    total_balance BIGINT DEFAULT 0,
    total_payments INTEGER DEFAULT 0,
    total_revenue_stars BIGINT DEFAULT 0,
    total_revenue_usd DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stats_date ON daily_balance_stats(date);

-- ═══════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL THEN
        NEW.referral_code = UPPER(SUBSTRING(MD5(NEW.telegram_id::TEXT || NOW()::TEXT) FROM 1 FOR 8));
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER generate_user_referral_code
    BEFORE INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION generate_referral_code();
