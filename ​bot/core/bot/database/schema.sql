-- Disable foreign keys temporarily during schema setup
PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY,
    first_name TEXT,
    username TEXT,
    language TEXT DEFAULT 'en',
    join_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL COLLATE NOCASE,
    project_slug TEXT UNIQUE NOT NULL,
    description TEXT,
    category_id INTEGER,
    telegram_post_link TEXT NOT NULL,
    status TEXT DEFAULT 'active', -- active, hidden, draft
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS project_keywords (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    keyword TEXT NOT NULL COLLATE NOCASE,
    FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS project_tags (
    project_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (project_id, tag_id),
    FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS project_stats (
    project_id INTEGER PRIMARY KEY,
    apk_clicks INTEGER DEFAULT 0,
    source_clicks INTEGER DEFAULT 0,
    zip_clicks INTEGER DEFAULT 0,
    pdf_clicks INTEGER DEFAULT 0,
    post_opens INTEGER DEFAULT 0,
    FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS search_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL COLLATE NOCASE,
    user_id INTEGER,
    matched_project_id INTEGER,
    search_time_ms INTEGER DEFAULT 0,
    pipeline_stage TEXT,
    cache_hit BOOLEAN DEFAULT 0,
    fts_hit BOOLEAN DEFAULT 0,
    rapidfuzz_score REAL DEFAULT 0.0,
    intent_score REAL DEFAULT 0.0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL,
    FOREIGN KEY (matched_project_id) REFERENCES projects (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL,
    record_id INTEGER NOT NULL,
    old_value TEXT,
    new_value TEXT,
    admin_id INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bookmarks (
    user_id INTEGER NOT NULL,
    project_id INTEGER NOT NULL,
    PRIMARY KEY (user_id, project_id),
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
);

-- Full Text Search (FTS5) External Content Synchronization
CREATE VIRTUAL TABLE IF NOT EXISTS projects_fts USING fts5(
    project_id UNINDEXED,
    name,
    description,
    keywords
);

-- -----------------------------------------------------------------------------
-- TRIGGERS: Resolving FTS5 Data Drift automatically within the Database Engine
-- -----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS projects_ai AFTER INSERT ON projects BEGIN
    INSERT INTO projects_fts(rowid, project_id, name, description, keywords)
    VALUES (new.id, new.id, new.name, new.description, '');
END;

CREATE TRIGGER IF NOT EXISTS projects_ad AFTER DELETE ON projects BEGIN
    INSERT INTO projects_fts(projects_fts, rowid, project_id, name, description, keywords)
    VALUES ('delete', old.id, old.id, old.name, old.description, '');
END;

CREATE TRIGGER IF NOT EXISTS projects_au AFTER UPDATE ON projects BEGIN
    INSERT INTO projects_fts(projects_fts, rowid, project_id, name, description, keywords)
    VALUES ('delete', old.id, old.id, old.name, old.description, '');
    
    INSERT INTO projects_fts(rowid, project_id, name, description, keywords)
    VALUES (
        new.id, 
        new.id, 
        new.name, 
        new.description, 
        (SELECT GROUP_CONCAT(keyword, ' ') FROM project_keywords WHERE project_id = new.id)
    );
END;

CREATE TRIGGER IF NOT EXISTS project_keywords_ai AFTER INSERT ON project_keywords BEGIN
    UPDATE projects_fts 
    SET keywords = (SELECT GROUP_CONCAT(keyword, ' ') FROM project_keywords WHERE project_id = new.project_id)
    WHERE project_id = new.project_id;
END;

CREATE TRIGGER IF NOT EXISTS project_keywords_ad AFTER DELETE ON project_keywords BEGIN
    UPDATE projects_fts 
    SET keywords = (SELECT GROUP_CONCAT(keyword, ' ') FROM project_keywords WHERE project_id = old.project_id)
    WHERE project_id = old.project_id;
END;

-- Timestamp auto-updater
CREATE TRIGGER IF NOT EXISTS update_projects_timestamp AFTER UPDATE ON projects FOR EACH ROW BEGIN
    UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

-- Fast Lookup Indexes
CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name);
CREATE INDEX IF NOT EXISTS idx_projects_slug ON projects(project_slug);
CREATE INDEX IF NOT EXISTS idx_projects_category ON projects(category_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_project_keywords_keyword ON project_keywords(keyword);

PRAGMA foreign_keys = ON;

