-- Script SQL para adicionar campos de antropometria aos usuários existentes
-- Executar isso após a aplicação rodar e criar as novas colunas

-- Adicionar valores padrão para usuários existentes que não tenham dados antropométricos
UPDATE users
SET
    weight = COALESCE(weight, 70.0),
    height = COALESCE(height, 170.0),
    age = COALESCE(age, 25),
    gender = COALESCE(gender, 'male')
WHERE weight IS NULL OR height IS NULL OR age IS NULL OR gender IS NULL;

-- Verificar os dados
SELECT id, name, email, weight, height, age, gender FROM users LIMIT 10;
