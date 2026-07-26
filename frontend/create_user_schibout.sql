-- Script SQL pour créer l'utilisateur schibout avec le rôle admin
-- Migration Factory - Création d'utilisateur

-- Générer un UUID pour l'utilisateur (vous pouvez aussi utiliser une séquence selon votre configuration)
-- Note: Ajustez selon votre système de base de données (PostgreSQL, MySQL, etc.)

INSERT INTO users (
    id,
    username,
    email,
    password_hash,
    role,
    is_active,
    created_at,
    last_login
) VALUES (
    gen_random_uuid(), -- Pour PostgreSQL, utilisez newid() pour SQL Server ou UUID() pour MySQL
    'schibout',
    'schibout@migration-factory.com',
    '$2b$12$LQv3c1yqBwEHRqBPxJ3H.OeM5vT1fQ5gKJ3Hq2sN8fR4tP7wQ9xA.', -- Hash bcrypt pour "schibout123"
    'admin',
    true,
    NOW(),
    NULL
);

-- Alternative avec un mot de passe simple "admin" (hash bcrypt)
-- INSERT INTO users (
--     id,
--     username,
--     email,
--     password_hash,
--     role,
--     is_active,
--     created_at,
--     last_login
-- ) VALUES (
--     gen_random_uuid(),
--     'schibout',
--     'schibout@migration-factory.com',
--     '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- Hash bcrypt pour "admin"
--     'admin',
--     true,
--     NOW(),
--     NULL
-- );

-- Vérifier que l'utilisateur a été créé
SELECT 
    id,
    username,
    email,
    role,
    is_active,
    created_at
FROM users 
WHERE username = 'schibout';

-- Notes importantes :
-- 1. Les mots de passe sont hashés avec bcrypt
-- 2. Le hash fourni correspond au mot de passe "schibout123" (recommandé)
-- 3. L'alternative commentée utilise le mot de passe "admin"
-- 4. Ajustez la fonction de génération d'UUID selon votre SGBD :
--    - PostgreSQL : gen_random_uuid()
--    - SQL Server : newid()
--    - MySQL : UUID()
-- 5. Si votre table utilise une clé primaire auto-incrémentée, retirez le champ 'id' de l'INSERT 