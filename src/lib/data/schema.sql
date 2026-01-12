-- VIBEE Leads Database Schema
-- Максимальная информация о клиентах для продаж

-- Таблица лидов
CREATE TABLE IF NOT EXISTS leads (
    id BIGSERIAL PRIMARY KEY,
    
    -- Telegram информация
    telegram_user_id BIGINT NOT NULL,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    
    -- Контактная информация
    full_name TEXT GENERATED ALWAYS AS (
        COALESCE(first_name || ' ', '') || COALESCE(last_name, '')
    ) STORED,
    
    -- Первый контакт
    first_message TEXT NOT NULL,
    first_message_date TIMESTAMPTZ DEFAULT NOW(),
    source_chat_id BIGINT NOT NULL,
    source_chat_name TEXT,
    
    -- Статус лида
    status TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'converted', 'lost')),
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    
    -- Интересы и намерения
    intent TEXT, -- 'buy', 'sell', 'exchange', 'info'
    crypto_interest TEXT[], -- ['bitcoin', 'usdt', 'ethereum']
    trigger_words TEXT[], -- Какие триггеры сработали
    
    -- Ответ агента
    agent_response TEXT,
    agent_response_date TIMESTAMPTZ,
    
    -- Метрики
    total_messages INT DEFAULT 1,
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    response_time_seconds INT, -- Как быстро ответили
    
    -- Дополнительная информация
    language TEXT DEFAULT 'ru',
    timezone TEXT,
    user_agent TEXT,
    
    -- Метаданные
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Индексы для быстрого поиска
    UNIQUE(telegram_user_id, source_chat_id)
);

-- Таблица истории сообщений лида
CREATE TABLE IF NOT EXISTS lead_messages (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE CASCADE,
    
    -- Сообщение
    message_text TEXT NOT NULL,
    message_date TIMESTAMPTZ DEFAULT NOW(),
    direction TEXT CHECK (direction IN ('incoming', 'outgoing')),
    
    -- Контекст
    chat_id BIGINT NOT NULL,
    message_id BIGINT,
    
    -- Анализ
    sentiment TEXT, -- 'positive', 'neutral', 'negative'
    contains_question BOOLEAN DEFAULT FALSE,
    contains_urgency BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Таблица действий с лидом
CREATE TABLE IF NOT EXISTS lead_actions (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE CASCADE,
    
    action_type TEXT NOT NULL, -- 'message_sent', 'forwarded', 'status_changed', 'note_added'
    action_data JSONB,
    performed_by TEXT DEFAULT 'agent',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Таблица заметок о лиде
CREATE TABLE IF NOT EXISTS lead_notes (
    id BIGSERIAL PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(id) ON DELETE CASCADE,
    
    note TEXT NOT NULL,
    note_type TEXT DEFAULT 'general', -- 'general', 'important', 'follow_up'
    created_by TEXT DEFAULT 'agent',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_leads_telegram_user_id ON leads(telegram_user_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_priority ON leads(priority);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_last_activity ON leads(last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_lead_messages_lead_id ON lead_messages(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_messages_date ON lead_messages(message_date DESC);
CREATE INDEX IF NOT EXISTS idx_lead_actions_lead_id ON lead_actions(lead_id);

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггер для автоматического обновления updated_at
CREATE TRIGGER update_leads_updated_at BEFORE UPDATE ON leads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- View для быстрого просмотра активных лидов
CREATE OR REPLACE VIEW active_leads AS
SELECT 
    l.id,
    l.telegram_user_id,
    l.username,
    l.full_name,
    l.first_message,
    l.status,
    l.priority,
    l.intent,
    l.crypto_interest,
    l.total_messages,
    l.last_activity,
    l.created_at,
    COUNT(lm.id) as message_count,
    MAX(lm.message_date) as last_message_date
FROM leads l
LEFT JOIN lead_messages lm ON l.id = lm.lead_id
WHERE l.status IN ('new', 'contacted', 'qualified')
GROUP BY l.id
ORDER BY l.priority DESC, l.last_activity DESC;

-- View для статистики
CREATE OR REPLACE VIEW lead_stats AS
SELECT 
    status,
    priority,
    COUNT(*) as count,
    AVG(total_messages) as avg_messages,
    AVG(response_time_seconds) as avg_response_time
FROM leads
GROUP BY status, priority;

-- Комментарии к таблицам
COMMENT ON TABLE leads IS 'Основная таблица лидов с максимальной информацией о клиентах';
COMMENT ON TABLE lead_messages IS 'История всех сообщений лида для анализа';
COMMENT ON TABLE lead_actions IS 'Лог всех действий с лидом';
COMMENT ON TABLE lead_notes IS 'Заметки менеджеров о лиде';

-- Начальные данные для тестирования
-- INSERT INTO leads (telegram_user_id, username, first_name, first_message, source_chat_id, source_chat_name, intent, crypto_interest, trigger_words)
-- VALUES (123456789, 'test_user', 'Test', 'куплю биткоин', -5082217642, 'Aimly.io dev', 'buy', ARRAY['bitcoin'], ARRAY['куплю биткоин']);
