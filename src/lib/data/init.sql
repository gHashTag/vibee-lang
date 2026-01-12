-- VIBEE Database Schema
-- Инициализационный SQL для PostgreSQL

-- Agents table - хранение состояния агентов
CREATE TABLE IF NOT EXISTS agents (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    tone VARCHAR(50) NOT NULL DEFAULT 'friendly',
    language VARCHAR(10) NOT NULL DEFAULT 'en',
    system_prompt TEXT,
    history_limit INTEGER NOT NULL DEFAULT 100,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Messages table - история сообщений
CREATE TABLE IF NOT EXISTS messages (
    id VARCHAR(255) PRIMARY KEY,
    agent_id VARCHAR(255) NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    sender VARCHAR(255) NOT NULL,
    content_type VARCHAR(50) NOT NULL DEFAULT 'text',
    content_text TEXT,
    content_url TEXT,
    content_caption TEXT,
    timestamp BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Telegram sessions table - MTProto сессии
CREATE TABLE IF NOT EXISTS telegram_sessions (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(50) UNIQUE NOT NULL,
    session_data BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Knowledge base table - RAG knowledge
CREATE TABLE IF NOT EXISTS knowledge (
    id SERIAL PRIMARY KEY,
    agent_id VARCHAR(255) REFERENCES agents(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    source VARCHAR(500),
    embedding VECTOR(1536), -- для OpenAI embeddings (optional)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_agent_id ON messages(agent_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_knowledge_agent_id ON knowledge(agent_id);

-- Triggers для updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_agents_updated_at
    BEFORE UPDATE ON agents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_telegram_sessions_updated_at
    BEFORE UPDATE ON telegram_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- TELEGRAM RAG TABLES - Полный парсинг диалогов с векторным поиском
-- =============================================================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Telegram Dialogs - чаты, группы, каналы
CREATE TABLE IF NOT EXISTS telegram_dialogs (
    id BIGINT PRIMARY KEY,
    type VARCHAR(20) NOT NULL CHECK (type IN ('user', 'group', 'channel', 'bot')),
    title VARCHAR(500),
    username VARCHAR(100),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    phone VARCHAR(50),
    participants_count INTEGER,
    is_verified BOOLEAN DEFAULT FALSE,
    is_restricted BOOLEAN DEFAULT FALSE,
    last_message_id BIGINT,
    last_parsed_at TIMESTAMPTZ,
    parse_status VARCHAR(20) DEFAULT 'pending' CHECK (parse_status IN ('pending', 'in_progress', 'completed', 'failed')),
    total_messages INTEGER DEFAULT 0,
    parsed_messages INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Telegram Messages - сообщения с embeddings
CREATE TABLE IF NOT EXISTS telegram_messages (
    id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL,
    dialog_id BIGINT NOT NULL REFERENCES telegram_dialogs(id) ON DELETE CASCADE,
    sender_id BIGINT,
    sender_name VARCHAR(255),
    content_type VARCHAR(50) DEFAULT 'text' CHECK (content_type IN ('text', 'photo', 'voice', 'video', 'document', 'sticker', 'animation', 'video_note', 'audio', 'contact', 'location', 'poll', 'other')),
    text_content TEXT,
    media_id BIGINT,
    reply_to_id BIGINT,
    forward_from_id BIGINT,
    forward_from_name VARCHAR(255),
    views_count INTEGER,
    forwards_count INTEGER,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    edit_date TIMESTAMPTZ,
    timestamp TIMESTAMPTZ NOT NULL,
    -- Embedding fields
    embedding VECTOR(1536),
    embedding_model VARCHAR(50),
    embedding_created_at TIMESTAMPTZ,
    -- Metadata
    raw_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(dialog_id, message_id)
);

-- 3. Telegram Media - медиа файлы с анализом
CREATE TABLE IF NOT EXISTS telegram_media (
    id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL,
    dialog_id BIGINT NOT NULL REFERENCES telegram_dialogs(id) ON DELETE CASCADE,
    media_type VARCHAR(50) NOT NULL CHECK (media_type IN ('photo', 'voice', 'video', 'document', 'audio', 'sticker', 'animation', 'video_note')),
    file_id VARCHAR(255),
    file_unique_id VARCHAR(255),
    file_path VARCHAR(500),
    file_name VARCHAR(255),
    file_size BIGINT,
    mime_type VARCHAR(100),
    width INTEGER,
    height INTEGER,
    duration_seconds INTEGER,
    -- Voice/Audio transcription
    transcription TEXT,
    transcription_model VARCHAR(50),
    transcription_language VARCHAR(10),
    transcription_confidence FLOAT,
    transcription_created_at TIMESTAMPTZ,
    -- Photo/Video analysis (Claude Vision)
    image_description TEXT,
    image_ocr_text TEXT,
    image_objects JSONB,  -- detected objects/labels
    vision_model VARCHAR(50),
    vision_created_at TIMESTAMPTZ,
    -- Content embedding (for transcriptions/descriptions)
    content_embedding VECTOR(1536),
    embedding_model VARCHAR(50),
    -- Processing status
    process_status VARCHAR(20) DEFAULT 'pending' CHECK (process_status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
    process_error TEXT,
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Parse Jobs - отслеживание задач парсинга
CREATE TABLE IF NOT EXISTS telegram_parse_jobs (
    id BIGSERIAL PRIMARY KEY,
    job_type VARCHAR(50) NOT NULL CHECK (job_type IN ('full_sync', 'dialog_sync', 'media_process', 'embedding_generate')),
    dialog_id BIGINT REFERENCES telegram_dialogs(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    progress_current INTEGER DEFAULT 0,
    progress_total INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    config JSONB,  -- job configuration (batch_size, delay_ms, etc)
    result JSONB,  -- job results summary
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEXES для быстрого поиска
-- =============================================================================

-- Dialog indexes
CREATE INDEX IF NOT EXISTS idx_dialogs_type ON telegram_dialogs(type);
CREATE INDEX IF NOT EXISTS idx_dialogs_parse_status ON telegram_dialogs(parse_status);
CREATE INDEX IF NOT EXISTS idx_dialogs_username ON telegram_dialogs(username) WHERE username IS NOT NULL;

-- Message indexes
CREATE INDEX IF NOT EXISTS idx_tg_messages_dialog ON telegram_messages(dialog_id);
CREATE INDEX IF NOT EXISTS idx_tg_messages_timestamp ON telegram_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_tg_messages_sender ON telegram_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_tg_messages_content_type ON telegram_messages(content_type);
CREATE INDEX IF NOT EXISTS idx_tg_messages_no_embedding ON telegram_messages(dialog_id)
    WHERE embedding IS NULL AND text_content IS NOT NULL AND LENGTH(text_content) > 10;

-- Media indexes
CREATE INDEX IF NOT EXISTS idx_media_dialog ON telegram_media(dialog_id);
CREATE INDEX IF NOT EXISTS idx_media_type ON telegram_media(media_type);
CREATE INDEX IF NOT EXISTS idx_media_process_status ON telegram_media(process_status);
CREATE INDEX IF NOT EXISTS idx_media_pending ON telegram_media(id)
    WHERE process_status = 'pending';

-- Parse jobs indexes
CREATE INDEX IF NOT EXISTS idx_parse_jobs_status ON telegram_parse_jobs(status);
CREATE INDEX IF NOT EXISTS idx_parse_jobs_dialog ON telegram_parse_jobs(dialog_id);

-- =============================================================================
-- VECTOR INDEXES (HNSW для быстрого семантического поиска)
-- =============================================================================

-- Message embeddings index (создаётся после наполнения данными)
-- HNSW: m=16 (connections), ef_construction=64 (build quality)
CREATE INDEX IF NOT EXISTS idx_tg_messages_embedding ON telegram_messages
    USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Media content embeddings index
CREATE INDEX IF NOT EXISTS idx_media_embedding ON telegram_media
    USING hnsw (content_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- =============================================================================
-- FULL-TEXT SEARCH (для гибридного поиска)
-- =============================================================================

-- Добавляем tsvector колонку для полнотекстового поиска (русский + английский)
ALTER TABLE telegram_messages ADD COLUMN IF NOT EXISTS text_search tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('russian', COALESCE(text_content, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(text_content, '')), 'B')
    ) STORED;

-- GIN индекс для полнотекстового поиска
CREATE INDEX IF NOT EXISTS idx_tg_messages_fts ON telegram_messages USING gin(text_search);

-- =============================================================================
-- GEMINI ANALYSIS FIELDS (расширение для мультимодального анализа)
-- =============================================================================

-- Добавляем новые поля для Gemini 2.5 Pro анализа
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS video_summary TEXT;
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS video_timestamps JSONB;
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS detected_emotions TEXT;
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS key_phrases JSONB;
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS speakers JSONB;
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS analysis_model VARCHAR(100);
ALTER TABLE telegram_media ADD COLUMN IF NOT EXISTS context_messages JSONB;

-- Индекс для поиска по ключевым фразам
CREATE INDEX IF NOT EXISTS idx_media_key_phrases ON telegram_media USING gin(key_phrases);

-- Индекс для поиска по эмоциям
CREATE INDEX IF NOT EXISTS idx_media_emotions ON telegram_media(detected_emotions);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE TRIGGER update_telegram_dialogs_updated_at
    BEFORE UPDATE ON telegram_dialogs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_telegram_media_updated_at
    BEFORE UPDATE ON telegram_media
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_telegram_parse_jobs_updated_at
    BEFORE UPDATE ON telegram_parse_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Функция для гибридного поиска (vector + keyword с RRF)
CREATE OR REPLACE FUNCTION hybrid_search(
    query_embedding VECTOR(1536),
    query_text TEXT,
    match_count INT DEFAULT 20,
    rrf_k INT DEFAULT 60
)
RETURNS TABLE (
    message_id BIGINT,
    dialog_id BIGINT,
    text_content TEXT,
    timestamp TIMESTAMPTZ,
    sender_name VARCHAR,
    vector_rank INT,
    keyword_rank INT,
    rrf_score FLOAT
) AS $$
WITH vector_search AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY embedding <=> query_embedding) AS rank
    FROM telegram_messages
    WHERE embedding IS NOT NULL
    ORDER BY embedding <=> query_embedding
    LIMIT match_count * 2
),
keyword_search AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY ts_rank(text_search, websearch_to_tsquery('russian', query_text)) DESC) AS rank
    FROM telegram_messages
    WHERE text_search @@ websearch_to_tsquery('russian', query_text)
    ORDER BY ts_rank(text_search, websearch_to_tsquery('russian', query_text)) DESC
    LIMIT match_count * 2
)
SELECT
    m.message_id,
    m.dialog_id,
    m.text_content,
    m.timestamp,
    m.sender_name,
    COALESCE(v.rank, 9999)::INT AS vector_rank,
    COALESCE(k.rank, 9999)::INT AS keyword_rank,
    (COALESCE(1.0 / (rrf_k + v.rank), 0.0) + COALESCE(1.0 / (rrf_k + k.rank), 0.0))::FLOAT AS rrf_score
FROM telegram_messages m
LEFT JOIN vector_search v ON m.id = v.id
LEFT JOIN keyword_search k ON m.id = k.id
WHERE v.id IS NOT NULL OR k.id IS NOT NULL
ORDER BY rrf_score DESC
LIMIT match_count;
$$ LANGUAGE SQL STABLE;

-- Функция для получения статистики парсинга
CREATE OR REPLACE FUNCTION get_parse_stats()
RETURNS TABLE (
    total_dialogs BIGINT,
    parsed_dialogs BIGINT,
    total_messages BIGINT,
    messages_with_embedding BIGINT,
    total_media BIGINT,
    processed_media BIGINT,
    pending_jobs BIGINT
) AS $$
SELECT
    (SELECT COUNT(*) FROM telegram_dialogs),
    (SELECT COUNT(*) FROM telegram_dialogs WHERE parse_status = 'completed'),
    (SELECT COUNT(*) FROM telegram_messages),
    (SELECT COUNT(*) FROM telegram_messages WHERE embedding IS NOT NULL),
    (SELECT COUNT(*) FROM telegram_media),
    (SELECT COUNT(*) FROM telegram_media WHERE process_status = 'completed'),
    (SELECT COUNT(*) FROM telegram_parse_jobs WHERE status IN ('pending', 'running'));
$$ LANGUAGE SQL STABLE;

-- =============================================================================
-- AI SERVICES TABLES - для AI генерации (ElevenLabs, Hedra, BFL, Kling, HeyGen)
-- =============================================================================

-- 1. AI Jobs - общая таблица для всех async AI операций
CREATE TABLE IF NOT EXISTS ai_jobs (
    id VARCHAR(100) PRIMARY KEY,
    job_type VARCHAR(50) NOT NULL CHECK (job_type IN (
        'elevenlabs_tts', 'elevenlabs_voice_clone',
        'hedra_avatar',
        'bfl_image',
        'kling_video', 'kling_image_to_video',
        'heygen_video'
    )),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'completed', 'failed', 'cancelled'
    )),
    user_id BIGINT,  -- optional, can link to users/agents
    agent_id VARCHAR(255) REFERENCES agents(id) ON DELETE SET NULL,
    input_data JSONB NOT NULL,  -- request parameters
    output_data JSONB,  -- result (URLs, metadata)
    error_message TEXT,
    external_job_id VARCHAR(255),  -- ID from external service
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. ElevenLabs TTS Generations
CREATE TABLE IF NOT EXISTS elevenlabs_generations (
    id BIGSERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE REFERENCES ai_jobs(id) ON DELETE CASCADE,
    user_id BIGINT,
    text TEXT NOT NULL,
    voice_id VARCHAR(100) NOT NULL,
    voice_name VARCHAR(255),
    model VARCHAR(50) DEFAULT 'eleven_multilingual_v2',
    stability FLOAT,
    similarity_boost FLOAT,
    audio_url TEXT,
    audio_duration_seconds FLOAT,
    characters_used INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Hedra Avatar Videos
CREATE TABLE IF NOT EXISTS hedra_avatars (
    id BIGSERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE REFERENCES ai_jobs(id) ON DELETE CASCADE,
    external_job_id VARCHAR(100),
    user_id BIGINT,
    audio_url TEXT NOT NULL,
    image_url TEXT NOT NULL,
    aspect_ratio VARCHAR(10) DEFAULT '1:1',
    result_url TEXT,
    thumbnail_url TEXT,
    duration_seconds FLOAT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. BFL/FLUX Image Generations
CREATE TABLE IF NOT EXISTS bfl_images (
    id BIGSERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE REFERENCES ai_jobs(id) ON DELETE CASCADE,
    task_id VARCHAR(100),
    user_id BIGINT,
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    model VARCHAR(50) DEFAULT 'flux-pro-1.1',
    width INTEGER DEFAULT 1024,
    height INTEGER DEFAULT 1024,
    steps INTEGER,
    guidance_scale FLOAT,
    seed BIGINT,
    result_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Kling AI Videos
CREATE TABLE IF NOT EXISTS kling_videos (
    id BIGSERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE REFERENCES ai_jobs(id) ON DELETE CASCADE,
    task_id VARCHAR(100),
    user_id BIGINT,
    generation_type VARCHAR(20) NOT NULL CHECK (generation_type IN ('text_to_video', 'image_to_video')),
    prompt TEXT,
    image_url TEXT,  -- for image_to_video
    mode VARCHAR(10) DEFAULT 'std' CHECK (mode IN ('std', 'pro')),
    duration INTEGER DEFAULT 5 CHECK (duration IN (5, 10)),
    aspect_ratio VARCHAR(10) DEFAULT '16:9',
    result_url TEXT,
    thumbnail_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. HeyGen Avatar Videos
CREATE TABLE IF NOT EXISTS heygen_videos (
    id BIGSERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE REFERENCES ai_jobs(id) ON DELETE CASCADE,
    video_id VARCHAR(100),
    user_id BIGINT,
    avatar_id VARCHAR(100) NOT NULL,
    avatar_name VARCHAR(255),
    script TEXT NOT NULL,
    voice_id VARCHAR(100),
    voice_name VARCHAR(255),
    background_url TEXT,
    result_url TEXT,
    thumbnail_url TEXT,
    duration_seconds FLOAT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- AI SERVICES INDEXES
-- =============================================================================

-- AI Jobs indexes
CREATE INDEX IF NOT EXISTS idx_ai_jobs_type ON ai_jobs(job_type);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status ON ai_jobs(status);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user ON ai_jobs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_jobs_agent ON ai_jobs(agent_id) WHERE agent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_jobs_pending ON ai_jobs(id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_ai_jobs_created ON ai_jobs(created_at DESC);

-- Service-specific indexes
CREATE INDEX IF NOT EXISTS idx_elevenlabs_voice ON elevenlabs_generations(voice_id);
CREATE INDEX IF NOT EXISTS idx_bfl_model ON bfl_images(model);
CREATE INDEX IF NOT EXISTS idx_kling_type ON kling_videos(generation_type);
CREATE INDEX IF NOT EXISTS idx_heygen_avatar ON heygen_videos(avatar_id);

-- =============================================================================
-- AI SERVICES TRIGGERS
-- =============================================================================

CREATE TRIGGER update_ai_jobs_updated_at
    BEFORE UPDATE ON ai_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_hedra_avatars_updated_at
    BEFORE UPDATE ON hedra_avatars
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bfl_images_updated_at
    BEFORE UPDATE ON bfl_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kling_videos_updated_at
    BEFORE UPDATE ON kling_videos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_heygen_videos_updated_at
    BEFORE UPDATE ON heygen_videos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- AI SERVICES HELPER FUNCTIONS
-- =============================================================================

-- Функция для получения статистики AI Jobs
CREATE OR REPLACE FUNCTION get_ai_stats()
RETURNS TABLE (
    total_jobs BIGINT,
    pending_jobs BIGINT,
    processing_jobs BIGINT,
    completed_jobs BIGINT,
    failed_jobs BIGINT,
    jobs_by_type JSONB
) AS $$
SELECT
    (SELECT COUNT(*) FROM ai_jobs),
    (SELECT COUNT(*) FROM ai_jobs WHERE status = 'pending'),
    (SELECT COUNT(*) FROM ai_jobs WHERE status = 'processing'),
    (SELECT COUNT(*) FROM ai_jobs WHERE status = 'completed'),
    (SELECT COUNT(*) FROM ai_jobs WHERE status = 'failed'),
    (SELECT jsonb_object_agg(job_type, cnt) FROM (
        SELECT job_type, COUNT(*) as cnt FROM ai_jobs GROUP BY job_type
    ) t);
$$ LANGUAGE SQL STABLE;

-- Функция для создания нового AI Job
CREATE OR REPLACE FUNCTION create_ai_job(
    p_id VARCHAR(100),
    p_job_type VARCHAR(50),
    p_input_data JSONB,
    p_user_id BIGINT DEFAULT NULL,
    p_agent_id VARCHAR(255) DEFAULT NULL
) RETURNS ai_jobs AS $$
DECLARE
    new_job ai_jobs;
BEGIN
    INSERT INTO ai_jobs (id, job_type, input_data, user_id, agent_id)
    VALUES (p_id, p_job_type, p_input_data, p_user_id, p_agent_id)
    RETURNING * INTO new_job;
    RETURN new_job;
END;
$$ LANGUAGE plpgsql;

-- Функция для обновления статуса AI Job
CREATE OR REPLACE FUNCTION update_ai_job_status(
    p_id VARCHAR(100),
    p_status VARCHAR(20),
    p_output_data JSONB DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_progress INTEGER DEFAULT NULL
) RETURNS ai_jobs AS $$
DECLARE
    updated_job ai_jobs;
BEGIN
    UPDATE ai_jobs SET
        status = p_status,
        output_data = COALESCE(p_output_data, output_data),
        error_message = COALESCE(p_error_message, error_message),
        progress = COALESCE(p_progress, progress),
        started_at = CASE WHEN p_status = 'processing' AND started_at IS NULL THEN NOW() ELSE started_at END,
        completed_at = CASE WHEN p_status IN ('completed', 'failed', 'cancelled') THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = p_id
    RETURNING * INTO updated_job;
    RETURN updated_job;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- BOT USER SESSIONS - состояние сцен для Telegram бота
-- =============================================================================

-- User Sessions - хранит текущую сцену и контекст пользователя
CREATE TABLE IF NOT EXISTS user_sessions (
    user_id BIGINT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    username VARCHAR(255) DEFAULT '',
    scene JSONB NOT NULL DEFAULT '{"type":"main","state":"idle"}',
    context JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User Photos (для сбора фото для обучения аватара)
CREATE TABLE IF NOT EXISTS user_photos (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    session_key VARCHAR(100) NOT NULL,  -- уникальный ключ сессии загрузки
    file_id TEXT NOT NULL,
    file_path TEXT,
    file_url TEXT,
    position INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User LoRA Models (обученные модели пользователей)
CREATE TABLE IF NOT EXISTS user_lora_models (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    trigger_word VARCHAR(100) NOT NULL,
    lora_url TEXT NOT NULL,
    training_id VARCHAR(255),
    training_status VARCHAR(20) DEFAULT 'completed',
    photos_count INTEGER DEFAULT 0,
    steps INTEGER DEFAULT 1000,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User Sessions Indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_updated ON user_sessions(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_scene ON user_sessions USING gin(scene);

-- User Photos Indexes
CREATE INDEX IF NOT EXISTS idx_user_photos_user ON user_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_user_photos_session ON user_photos(session_key);

-- User LoRA Models Indexes
CREATE INDEX IF NOT EXISTS idx_user_lora_user ON user_lora_models(user_id);
CREATE INDEX IF NOT EXISTS idx_user_lora_trigger ON user_lora_models(trigger_word);

-- Triggers
CREATE TRIGGER update_user_sessions_updated_at
    BEFORE UPDATE ON user_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_lora_models_updated_at
    BEFORE UPDATE ON user_lora_models
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CLIENT ONBOARDING (Auto onboarding after MCP connection)
-- =============================================================================

-- Client onboarding sessions
CREATE TABLE IF NOT EXISTS client_onboarding (
    id SERIAL PRIMARY KEY,
    onboarding_id VARCHAR(50) UNIQUE NOT NULL,
    session_id TEXT NOT NULL,
    phone VARCHAR(50),
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    auto_select BOOLEAN DEFAULT FALSE,
    scan_job_id INT REFERENCES telegram_parse_jobs(id),
    selected_dialog_ids BIGINT[],
    dialogs_count INT DEFAULT 0,
    messages_count INT DEFAULT 0,
    embeddings_count INT DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Onboarding indexes
CREATE INDEX IF NOT EXISTS idx_onboarding_session ON client_onboarding(session_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_status ON client_onboarding(status);
CREATE INDEX IF NOT EXISTS idx_onboarding_phone ON client_onboarding(phone);

-- Onboarding update trigger
CREATE TRIGGER update_client_onboarding_updated_at
    BEFORE UPDATE ON client_onboarding
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PAYMENTS (From 999-multibots-telegraf integration)
-- =============================================================================

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    inv_id VARCHAR(50) UNIQUE NOT NULL,
    telegram_id BIGINT NOT NULL,
    amount DECIMAL(12,4) NOT NULL,
    stars INT NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL CHECK (currency IN ('XTR', 'RUB', 'USDT', 'TON')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('telegram', 'robokassa', 'ton_usdt', 'ton_native')),
    description TEXT,
    invoice_url TEXT,
    metadata JSONB DEFAULT '{}',
    tx_hash VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Payment indexes
CREATE INDEX IF NOT EXISTS idx_payments_telegram_id ON payments(telegram_id);
CREATE INDEX IF NOT EXISTS idx_payments_inv_id ON payments(inv_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);

-- User balances table
CREATE TABLE IF NOT EXISTS user_balances (
    telegram_id BIGINT PRIMARY KEY,
    stars_balance INT NOT NULL DEFAULT 0,
    total_deposited INT NOT NULL DEFAULT 0,
    total_spent INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Balance index
CREATE INDEX IF NOT EXISTS idx_user_balances_balance ON user_balances(stars_balance);

-- Payment update trigger
CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Balance update trigger
CREATE TRIGGER update_user_balances_updated_at
    BEFORE UPDATE ON user_balances
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to update user balance on payment completion
CREATE OR REPLACE FUNCTION update_balance_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status = 'PENDING' THEN
        INSERT INTO user_balances (telegram_id, stars_balance, total_deposited)
        VALUES (NEW.telegram_id, NEW.stars, NEW.stars)
        ON CONFLICT (telegram_id) DO UPDATE
        SET stars_balance = user_balances.stars_balance + NEW.stars,
            total_deposited = user_balances.total_deposited + NEW.stars,
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update balance
CREATE TRIGGER payment_completed_update_balance
    AFTER UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_balance_on_payment();

-- =============================================================================
-- P2P ESCROW SYSTEM
-- =============================================================================

-- P2P Orders - основная таблица ордеров
CREATE TABLE IF NOT EXISTS p2p_orders (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(50) UNIQUE NOT NULL,  -- P2P-{telegram_id}-{timestamp}
    seller_telegram_id BIGINT NOT NULL,
    seller_wallet VARCHAR(100) NOT NULL,
    buyer_telegram_id BIGINT,
    buyer_wallet VARCHAR(100),
    crypto VARCHAR(10) NOT NULL CHECK (crypto IN ('TON', 'USDT')),
    crypto_amount DECIMAL(18,6) NOT NULL,
    fiat VARCHAR(10) NOT NULL CHECK (fiat IN ('THB', 'RUB', 'USD', 'EUR')),
    fiat_amount DECIMAL(18,2) NOT NULL,
    rate DECIMAL(18,6) NOT NULL,  -- fiat_amount / crypto_amount
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN (
        'bangkok_bank', 'promptpay', 'sberbank', 'tinkoff', 'wise', 'bank_transfer'
    )),
    payment_details TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN (
        'open', 'locked', 'fiat_sent', 'completed', 'disputed', 'cancelled', 'expired'
    )),
    escrow_tx_hash VARCHAR(100),  -- Seller's deposit TX
    release_tx_hash VARCHAR(100),  -- Release to buyer TX
    escrow_address VARCHAR(100),  -- Escrow contract address
    expires_at TIMESTAMPTZ,  -- Order expiration (24h default)
    locked_at TIMESTAMPTZ,  -- When buyer locked
    payment_deadline TIMESTAMPTZ,  -- 30 min after lock
    fiat_sent_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- P2P Trader Profiles - репутация трейдеров
CREATE TABLE IF NOT EXISTS p2p_traders (
    telegram_id BIGINT PRIMARY KEY,
    username VARCHAR(100),
    wallet_address VARCHAR(100),
    completed_trades INT NOT NULL DEFAULT 0,
    total_volume_usd DECIMAL(18,2) NOT NULL DEFAULT 0,
    avg_rating DECIMAL(3,2) NOT NULL DEFAULT 5.0 CHECK (avg_rating >= 0 AND avg_rating <= 5),
    disputes_as_seller INT NOT NULL DEFAULT 0,
    disputes_as_buyer INT NOT NULL DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    first_trade_at TIMESTAMPTZ,
    last_trade_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- P2P Disputes - споры по сделкам
CREATE TABLE IF NOT EXISTS p2p_disputes (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL REFERENCES p2p_orders(order_id) ON DELETE CASCADE,
    opened_by BIGINT NOT NULL,  -- telegram_id who opened
    reason VARCHAR(50) NOT NULL CHECK (reason IN (
        'no_payment', 'wrong_amount', 'no_release', 'fraud', 'other'
    )),
    description TEXT,
    evidence_urls TEXT[],  -- Screenshots, etc
    resolution VARCHAR(30) CHECK (resolution IN (
        'pending', 'seller_wins', 'buyer_wins', 'split', 'cancelled'
    )) DEFAULT 'pending',
    resolved_by BIGINT,  -- Admin telegram_id
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- P2P Trade Ratings - рейтинги после сделок
CREATE TABLE IF NOT EXISTS p2p_ratings (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL REFERENCES p2p_orders(order_id) ON DELETE CASCADE,
    rater_telegram_id BIGINT NOT NULL,
    rated_telegram_id BIGINT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(order_id, rater_telegram_id)  -- One rating per order per user
);

-- P2P Market Rates - текущие курсы
CREATE TABLE IF NOT EXISTS p2p_rates (
    id SERIAL PRIMARY KEY,
    crypto VARCHAR(10) NOT NULL,
    fiat VARCHAR(10) NOT NULL,
    buy_rate DECIMAL(18,6) NOT NULL,  -- Rate to buy crypto
    sell_rate DECIMAL(18,6) NOT NULL,  -- Rate to sell crypto
    spread_percent DECIMAL(5,2) NOT NULL DEFAULT 1.0,
    source VARCHAR(50) DEFAULT 'manual',  -- 'coingecko', 'binance', 'manual'
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(crypto, fiat)
);

-- P2P Platform Config - конфигурация платформы
CREATE TABLE IF NOT EXISTS p2p_config (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default config
INSERT INTO p2p_config (key, value, description) VALUES
    ('platform_fee_percent', '0.5', 'Platform fee in percent'),
    ('min_order_usd', '10', 'Minimum order in USD equivalent'),
    ('max_order_usd', '10000', 'Maximum order in USD equivalent'),
    ('order_expiry_hours', '24', 'Order expiration in hours'),
    ('payment_timeout_minutes', '30', 'Payment timeout after lock'),
    ('auto_confirm_threshold_usd', '500', 'Auto-confirm for trusted traders under this amount'),
    ('escrow_wallet', 'UQ...', 'Escrow smart contract address')
ON CONFLICT (key) DO NOTHING;

-- Insert default rates
INSERT INTO p2p_rates (crypto, fiat, buy_rate, sell_rate, spread_percent, source) VALUES
    ('USDT', 'THB', 35.00, 34.50, 1.45, 'manual'),
    ('USDT', 'RUB', 94.00, 92.00, 2.17, 'manual'),
    ('USDT', 'USD', 1.001, 0.999, 0.2, 'manual'),
    ('USDT', 'EUR', 0.93, 0.91, 2.2, 'manual'),
    ('TON', 'THB', 210.00, 200.00, 5.0, 'manual'),
    ('TON', 'RUB', 570.00, 550.00, 3.64, 'manual')
ON CONFLICT (crypto, fiat) DO NOTHING;

-- =============================================================================
-- P2P INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_p2p_orders_seller ON p2p_orders(seller_telegram_id);
CREATE INDEX IF NOT EXISTS idx_p2p_orders_buyer ON p2p_orders(buyer_telegram_id) WHERE buyer_telegram_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_p2p_orders_status ON p2p_orders(status);
CREATE INDEX IF NOT EXISTS idx_p2p_orders_crypto_fiat ON p2p_orders(crypto, fiat);
CREATE INDEX IF NOT EXISTS idx_p2p_orders_open ON p2p_orders(crypto, fiat) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_p2p_orders_created ON p2p_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_p2p_disputes_order ON p2p_disputes(order_id);
CREATE INDEX IF NOT EXISTS idx_p2p_disputes_pending ON p2p_disputes(id) WHERE resolution = 'pending';
CREATE INDEX IF NOT EXISTS idx_p2p_ratings_rated ON p2p_ratings(rated_telegram_id);

-- =============================================================================
-- P2P TRIGGERS
-- =============================================================================

CREATE TRIGGER update_p2p_orders_updated_at
    BEFORE UPDATE ON p2p_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_p2p_traders_updated_at
    BEFORE UPDATE ON p2p_traders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_p2p_disputes_updated_at
    BEFORE UPDATE ON p2p_disputes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- P2P HELPER FUNCTIONS
-- =============================================================================

-- Update trader stats after completed trade
CREATE OR REPLACE FUNCTION update_trader_stats()
RETURNS TRIGGER AS $$
DECLARE
    usd_amount DECIMAL;
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Calculate USD equivalent (simplified)
        usd_amount := CASE NEW.fiat
            WHEN 'USD' THEN NEW.fiat_amount
            WHEN 'THB' THEN NEW.fiat_amount / 35.0
            WHEN 'RUB' THEN NEW.fiat_amount / 93.0
            WHEN 'EUR' THEN NEW.fiat_amount * 1.08
            ELSE NEW.fiat_amount
        END;

        -- Update seller
        INSERT INTO p2p_traders (telegram_id, completed_trades, total_volume_usd, first_trade_at, last_trade_at)
        VALUES (NEW.seller_telegram_id, 1, usd_amount, NOW(), NOW())
        ON CONFLICT (telegram_id) DO UPDATE SET
            completed_trades = p2p_traders.completed_trades + 1,
            total_volume_usd = p2p_traders.total_volume_usd + usd_amount,
            last_trade_at = NOW(),
            first_trade_at = COALESCE(p2p_traders.first_trade_at, NOW());

        -- Update buyer
        IF NEW.buyer_telegram_id IS NOT NULL THEN
            INSERT INTO p2p_traders (telegram_id, completed_trades, total_volume_usd, first_trade_at, last_trade_at)
            VALUES (NEW.buyer_telegram_id, 1, usd_amount, NOW(), NOW())
            ON CONFLICT (telegram_id) DO UPDATE SET
                completed_trades = p2p_traders.completed_trades + 1,
                total_volume_usd = p2p_traders.total_volume_usd + usd_amount,
                last_trade_at = NOW(),
                first_trade_at = COALESCE(p2p_traders.first_trade_at, NOW());
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER p2p_order_completed_update_stats
    AFTER UPDATE ON p2p_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_trader_stats();

-- Update trader rating after new rating
CREATE OR REPLACE FUNCTION update_trader_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE p2p_traders
    SET avg_rating = (
        SELECT AVG(rating)::DECIMAL(3,2)
        FROM p2p_ratings
        WHERE rated_telegram_id = NEW.rated_telegram_id
    )
    WHERE telegram_id = NEW.rated_telegram_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER p2p_rating_update_avg
    AFTER INSERT ON p2p_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_trader_rating();

-- Get P2P statistics
CREATE OR REPLACE FUNCTION get_p2p_stats()
RETURNS TABLE (
    total_orders BIGINT,
    open_orders BIGINT,
    completed_orders BIGINT,
    total_volume_usd DECIMAL,
    total_traders BIGINT,
    pending_disputes BIGINT
) AS $$
SELECT
    (SELECT COUNT(*) FROM p2p_orders),
    (SELECT COUNT(*) FROM p2p_orders WHERE status = 'open'),
    (SELECT COUNT(*) FROM p2p_orders WHERE status = 'completed'),
    (SELECT COALESCE(SUM(total_volume_usd), 0) FROM p2p_traders),
    (SELECT COUNT(*) FROM p2p_traders WHERE completed_trades > 0),
    (SELECT COUNT(*) FROM p2p_disputes WHERE resolution = 'pending');
$$ LANGUAGE SQL STABLE;

-- =============================================================================
-- USER SERVICES - Digital Clone Services Database
-- =============================================================================

-- User services table - услуги пользователя для Digital Clone
CREATE TABLE IF NOT EXISTS user_services (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    description TEXT,
    price_range VARCHAR(100),
    keywords TEXT[],
    embedding VECTOR(1536),  -- для semantic matching
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User voice profile - стиль общения пользователя
CREATE TABLE IF NOT EXISTS user_voice_profiles (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL,
    avg_message_length INT DEFAULT 0,
    formality_level DECIMAL(3,2) DEFAULT 0.5,  -- 0.0 = casual, 1.0 = formal
    emoji_frequency DECIMAL(3,2) DEFAULT 0.0,
    signature_phrases TEXT[],
    typical_greetings TEXT[],
    typical_closings TEXT[],
    language_preference VARCHAR(10) DEFAULT 'ru',
    analyzed_messages_count INT DEFAULT 0,
    last_analyzed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for user_services
CREATE INDEX IF NOT EXISTS idx_user_services_telegram_id ON user_services(telegram_id);
CREATE INDEX IF NOT EXISTS idx_user_services_active ON user_services(telegram_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_services_embedding ON user_services USING hnsw (embedding vector_cosine_ops);

-- Indexes for voice profiles
CREATE INDEX IF NOT EXISTS idx_voice_profiles_telegram_id ON user_voice_profiles(telegram_id);

-- Updated_at trigger for user_services
CREATE TRIGGER update_user_services_updated_at
    BEFORE UPDATE ON user_services
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Updated_at trigger for voice profiles
CREATE TRIGGER update_voice_profiles_updated_at
    BEFORE UPDATE ON user_voice_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to match service by query embedding
CREATE OR REPLACE FUNCTION match_user_services(
    p_telegram_id BIGINT,
    p_query_embedding VECTOR(1536),
    p_limit INT DEFAULT 3
)
RETURNS TABLE (
    service_id INT,
    service_name VARCHAR(255),
    description TEXT,
    price_range VARCHAR(100),
    similarity FLOAT
) AS $$
SELECT
    id,
    service_name,
    description,
    price_range,
    1 - (embedding <=> p_query_embedding) as similarity
FROM user_services
WHERE telegram_id = p_telegram_id
  AND is_active = true
  AND embedding IS NOT NULL
ORDER BY embedding <=> p_query_embedding
LIMIT p_limit;
$$ LANGUAGE SQL STABLE;

-- =============================================================================
-- TaskFlow: Collaborative Task Management System
-- =============================================================================

-- User tasks table - main task storage (renamed from tasks to avoid conflict with Eliza agent tasks)
CREATE TABLE IF NOT EXISTS user_tasks (
    id SERIAL PRIMARY KEY,
    owner_telegram_id BIGINT NOT NULL,                              -- Task creator
    contact_dialog_id BIGINT REFERENCES telegram_dialogs(id),       -- Linked contact
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'other',                           -- conversation, meeting, project, promise, other
    status VARCHAR(20) DEFAULT 'pending',                           -- pending, in_progress, waiting, completed, cancelled
    priority INT DEFAULT 2,                                         -- 1=high, 2=medium, 3=low
    responsibility VARCHAR(20) DEFAULT 'owner',                     -- owner, contact, both
    due_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task status history - audit trail
CREATE TABLE IF NOT EXISTS user_task_status_history (
    id SERIAL PRIMARY KEY,
    task_id INT REFERENCES user_tasks(id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    changed_by VARCHAR(20),                                         -- owner, contact
    comment TEXT,
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task comments
CREATE TABLE IF NOT EXISTS user_task_comments (
    id SERIAL PRIMARY KEY,
    task_id INT REFERENCES user_tasks(id) ON DELETE CASCADE,
    author_telegram_id BIGINT NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task reminders
CREATE TABLE IF NOT EXISTS user_task_reminders (
    id SERIAL PRIMARY KEY,
    task_id INT REFERENCES user_tasks(id) ON DELETE CASCADE,
    remind_at TIMESTAMPTZ NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ
);

-- Indexes for user_tasks
CREATE INDEX IF NOT EXISTS idx_user_tasks_owner ON user_tasks(owner_telegram_id);
CREATE INDEX IF NOT EXISTS idx_user_tasks_contact ON user_tasks(contact_dialog_id);
CREATE INDEX IF NOT EXISTS idx_user_tasks_status ON user_tasks(status);
CREATE INDEX IF NOT EXISTS idx_user_tasks_due ON user_tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_tasks_active ON user_tasks(owner_telegram_id, archived) WHERE archived = false;

-- Indexes for reminders
CREATE INDEX IF NOT EXISTS idx_user_task_reminders_pending ON user_task_reminders(remind_at) WHERE NOT is_sent;
CREATE INDEX IF NOT EXISTS idx_user_task_reminders_task ON user_task_reminders(task_id);

-- Indexes for status history
CREATE INDEX IF NOT EXISTS idx_user_task_status_history_task ON user_task_status_history(task_id);

-- Indexes for comments
CREATE INDEX IF NOT EXISTS idx_user_task_comments_task ON user_task_comments(task_id);

-- Updated_at trigger for user_tasks
DROP TRIGGER IF EXISTS update_user_tasks_updated_at ON user_tasks;
CREATE TRIGGER update_user_tasks_updated_at
    BEFORE UPDATE ON user_tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Extracted Task Sources - Links tasks to source messages
-- =============================================================================

CREATE TABLE IF NOT EXISTS extracted_task_sources (
    id SERIAL PRIMARY KEY,
    task_id INT REFERENCES user_tasks(id) ON DELETE CASCADE,
    message_id INT NOT NULL,
    dialog_id BIGINT NOT NULL,
    extraction_confidence FLOAT NOT NULL DEFAULT 0.0,
    extracted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for extracted_task_sources
CREATE INDEX IF NOT EXISTS idx_extracted_task_sources_task ON extracted_task_sources(task_id);
CREATE INDEX IF NOT EXISTS idx_extracted_task_sources_dialog ON extracted_task_sources(dialog_id);
CREATE INDEX IF NOT EXISTS idx_extracted_task_sources_message ON extracted_task_sources(message_id);
