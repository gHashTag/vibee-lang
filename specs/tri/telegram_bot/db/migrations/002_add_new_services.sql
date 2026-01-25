-- ═══════════════════════════════════════════════════════════════
-- VIBEE Telegram Bot - New Services Migration
-- Adds support for new Replicate models
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- SERVICE PRICES TABLE
-- Centralized pricing for all services
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS service_prices (
    id SERIAL PRIMARY KEY,
    service_id VARCHAR(100) UNIQUE NOT NULL,
    name_ru VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- image, video, audio, avatar, tools
    model_id VARCHAR(255), -- Replicate model ID
    base_cost_usd DECIMAL(10, 6) NOT NULL,
    cost_stars INTEGER NOT NULL,
    cost_unit VARCHAR(50) DEFAULT 'per_request', -- per_request, per_second, per_minute, per_1000_chars
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert pricing for all services (150% markup: stars = (usd / 0.016) * 1.5)
INSERT INTO service_prices (service_id, name_ru, name_en, category, model_id, base_cost_usd, cost_stars, cost_unit) VALUES
-- Image services
('neuro_photo', 'Нейрофото', 'Neuro Photo', 'image', NULL, 0.08, 7, 'per_request'),
('neuro_photo_v2', 'Нейрофото V2', 'Neuro Photo V2', 'image', NULL, 0.14, 13, 'per_request'),
('fast_image_gen', 'Быстрая генерация', 'Fast Generation', 'image', 'prunaai/z-image-turbo', 0.005, 1, 'per_request'),
('fast_image_edit', 'Быстрое редактирование', 'Fast Edit', 'image', 'prunaai/p-image-edit', 0.01, 1, 'per_request'),
('background_removal', 'Удаление фона', 'Background Removal', 'image', 'lucataco/remove-bg', 0.00052, 1, 'per_request'),
('sketch_to_image', 'Скетч в фото', 'Sketch to Image', 'image', 'bytedance/seedream-4', 0.03, 3, 'per_request'),
('image_to_prompt', 'Фото в промпт', 'Image to Prompt', 'image', NULL, 0.03, 2, 'per_request'),
('image_upscaler', 'Улучшение качества', 'Image Upscaler', 'image', NULL, 0.04, 3, 'per_request'),
('face_swap', 'Замена лица', 'Face Swap', 'image', 'codeplugtech/face-swap', 0.10, 10, 'per_request'),

-- Video services
('text_to_video', 'Текст в видео', 'Text to Video', 'video', NULL, 0.50, 47, 'per_5_seconds'),
('image_to_video', 'Фото в видео', 'Image to Video', 'video', NULL, 0.40, 38, 'per_5_seconds'),
('video_upscaler', 'Апскейл видео', 'Video Upscaler', 'video', 'philz1337x/crystal-video-upscaler', 0.10, 9, 'per_second'),
('motion_control', 'Управление движением', 'Motion Control', 'video', 'kwaivgi/kling-v2.6-motion-control', 0.40, 38, 'per_5_seconds'),
('lip_sync', 'Синхронизация губ', 'Lip Sync', 'video', NULL, 0.90, 84, 'per_request'),

-- Audio services
('text_to_speech', 'Текст в голос', 'Text to Speech', 'audio', NULL, 0.12, 11, 'per_request'),
('fast_tts', 'Быстрый TTS', 'Fast TTS', 'audio', 'resemble-ai/chatterbox-turbo', 0.02, 2, 'per_1000_chars'),
('voice_clone', 'Клонирование голоса', 'Voice Clone', 'audio', NULL, 0.90, 84, 'per_request'),
('music_generation', 'Генерация музыки', 'Music Generation', 'audio', 'minimax/music-1.5', 0.05, 5, 'per_10_seconds'),
('voice_to_text', 'Голос в текст', 'Voice to Text', 'audio', NULL, 0.08, 7, 'per_request'),
('video_transcription', 'Транскрипция видео', 'Video Transcription', 'audio', 'turian/insanely-fast-whisper-with-video', 0.088, 8, 'per_request'),

-- Tools
('nsfw_detection', 'Проверка NSFW', 'NSFW Detection', 'tools', 'falcons-ai/nsfw_image_detection', 0.0005, 0, 'per_request')

ON CONFLICT (service_id) DO UPDATE SET
    base_cost_usd = EXCLUDED.base_cost_usd,
    cost_stars = EXCLUDED.cost_stars,
    updated_at = NOW();

-- ═══════════════════════════════════════════════════════════════
-- GENERATION QUEUE TABLE
-- For async processing of long-running tasks
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS generation_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    service_id VARCHAR(100) NOT NULL,
    input_data JSONB NOT NULL,
    replicate_prediction_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed
    result_url TEXT,
    error TEXT,
    cost_stars INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT fk_queue_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_queue_telegram_id ON generation_queue(telegram_id);
CREATE INDEX idx_queue_status ON generation_queue(status);
CREATE INDEX idx_queue_replicate_id ON generation_queue(replicate_prediction_id);

-- ═══════════════════════════════════════════════════════════════
-- CRYPTOBOT PAYMENTS TABLE
-- For USDT payments via CryptoBot
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cryptobot_invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    invoice_id BIGINT UNIQUE,
    amount_usdt DECIMAL(10, 4) NOT NULL,
    amount_stars INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'active', -- active, paid, expired
    bot_invoice_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    
    CONSTRAINT fk_crypto_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_crypto_telegram_id ON cryptobot_invoices(telegram_id);
CREATE INDEX idx_crypto_invoice_id ON cryptobot_invoices(invoice_id);
CREATE INDEX idx_crypto_status ON cryptobot_invoices(status);

-- ═══════════════════════════════════════════════════════════════
-- USER VOICES TABLE
-- For cloned voices (ElevenLabs)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_voices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL,
    voice_id VARCHAR(255) NOT NULL, -- ElevenLabs voice ID
    name VARCHAR(255) NOT NULL,
    preview_url TEXT,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_voices_user FOREIGN KEY (telegram_id) 
        REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE INDEX idx_voices_telegram_id ON user_voices(telegram_id);

-- ═══════════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════════

CREATE TRIGGER update_service_prices_updated_at
    BEFORE UPDATE ON service_prices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
