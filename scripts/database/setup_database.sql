
-- HEALTHCARE LAB RESULTS - DATABASE SCHEMA


-- Habilitar extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- TABLA: patients

CREATE TABLE IF NOT EXISTS patients (
    patient_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system',
    updated_by VARCHAR(100) DEFAULT 'system',
    
    -- Soft delete
    deleted_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- Índices
CREATE INDEX idx_patients_email ON patients(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_patients_active ON patients(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_patients_created ON patients(created_at);

-- Comentarios
COMMENT ON TABLE patients IS 'Información de pacientes';
COMMENT ON COLUMN patients.patient_id IS 'ID único del paciente (del sistema del laboratorio)';
COMMENT ON COLUMN patients.email IS 'Correo electrónico del paciente y único del paciente2';


-- TABLA: lab_results
CREATE TABLE IF NOT EXISTS lab_results (
    result_id SERIAL PRIMARY KEY,
    
    -- Referencias
    patient_id VARCHAR(50) NOT NULL,
    
    -- Información del laboratorio
    lab_id VARCHAR(50) NOT NULL,
    lab_name VARCHAR(255) NOT NULL,
    test_type VARCHAR(100) NOT NULL,
    test_date TIMESTAMP NOT NULL,
    
    -- Médico
    physician_name VARCHAR(255),
    physician_npi VARCHAR(20),
    
    -- Estado del procesamiento
    status VARCHAR(20) DEFAULT 'pending',
    processing_started_at TIMESTAMP,
    processing_completed_at TIMESTAMP,
    error_message TEXT,
    
    -- Ubicaciones S3
    s3_raw_bucket VARCHAR(255),
    s3_raw_key VARCHAR(512),
    s3_processed_bucket VARCHAR(255),
    s3_processed_key VARCHAR(512),
    
    -- Notas adicionales
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Keys
    CONSTRAINT fk_patient 
        FOREIGN KEY (patient_id) 
        REFERENCES patients(patient_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT valid_status 
        CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'archived'))
);

-- Índices
CREATE INDEX idx_lab_results_patient ON lab_results(patient_id);
CREATE INDEX idx_lab_results_status ON lab_results(status);
CREATE INDEX idx_lab_results_test_date ON lab_results(test_date DESC);
CREATE INDEX idx_lab_results_test_type ON lab_results(test_type);
CREATE INDEX idx_lab_results_created ON lab_results(created_at DESC);

-- Full-text search
CREATE INDEX idx_lab_results_search ON lab_results 
    USING gin(to_tsvector('english', 
        coalesce(test_type, '') || ' ' || 
        coalesce(notes, '')
    ));

COMMENT ON TABLE lab_results IS 'Resultados de laboratorio';
COMMENT ON COLUMN lab_results.status IS 'Estado: pending, processing, completed, failed, archived';

-- ============================================
-- TABLA: test_values
-- ============================================
CREATE TABLE IF NOT EXISTS test_values (
    id SERIAL PRIMARY KEY,
    
    -- Referencias
    result_id INTEGER NOT NULL,
    
    -- Información del test
    test_code VARCHAR(20) NOT NULL,
    test_name VARCHAR(255) NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    reference_range VARCHAR(100),
    is_abnormal BOOLEAN DEFAULT FALSE,
    
    -- Flags adicionales
    severity VARCHAR(20),  -- low, high, critical
    alert_flag BOOLEAN DEFAULT FALSE,
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Keys
    CONSTRAINT fk_lab_result 
        FOREIGN KEY (result_id) 
        REFERENCES lab_results(result_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT valid_severity 
        CHECK (severity IN ('normal', 'low', 'high', 'critical', NULL))
);

-- Índices
CREATE INDEX idx_test_values_result ON test_values(result_id);
CREATE INDEX idx_test_values_code ON test_values(test_code);
CREATE INDEX idx_test_values_abnormal ON test_values(is_abnormal) WHERE is_abnormal = TRUE;
CREATE INDEX idx_test_values_alert ON test_values(alert_flag) WHERE alert_flag = TRUE;

COMMENT ON TABLE test_values IS 'Valores individuales de cada test en un resultado';

-- ============================================
-- TABLA: audit_log (para compliance)
-- ============================================
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    
    -- Información del evento
    event_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id VARCHAR(100),
    
    -- Usuario y timestamp
    user_id VARCHAR(100),
    user_email VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    
    -- Detalles del cambio
    old_values JSONB,
    new_values JSONB,
    changes JSONB,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_event_type 
        CHECK (event_type IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'ACCESS', 'DOWNLOAD'))
);

-- Índices
CREATE INDEX idx_audit_log_type ON audit_log(event_type);
CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- Particionamiento por fecha (opcional para grandes volúmenes)
-- CREATE TABLE audit_log_2024_01 PARTITION OF audit_log
--     FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

COMMENT ON TABLE audit_log IS 'Log de auditoría para compliance (HIPAA)';

-- ============================================
-- TABLA: processing_queue_status (tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS processing_queue_status (
    id SERIAL PRIMARY KEY,
    
    -- SQS Message Info
    message_id VARCHAR(255) UNIQUE NOT NULL,
    receipt_handle TEXT,
    
    -- Processing Info
    s3_bucket VARCHAR(255) NOT NULL,
    s3_key VARCHAR(512) NOT NULL,
    result_id INTEGER,
    
    -- Status
    status VARCHAR(50) DEFAULT 'received',
    attempt_count INTEGER DEFAULT 0,
    last_attempt_at TIMESTAMP,
    error_message TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Foreign Keys
    CONSTRAINT fk_processing_result 
        FOREIGN KEY (result_id) 
        REFERENCES lab_results(result_id)
        ON DELETE SET NULL,
    
    -- Constraints
    CONSTRAINT valid_processing_status 
        CHECK (status IN ('received', 'processing', 'completed', 'failed', 'dlq'))
);

-- Índices
CREATE INDEX idx_queue_status_message ON processing_queue_status(message_id);
CREATE INDEX idx_queue_status_status ON processing_queue_status(status);
CREATE INDEX idx_queue_status_result ON processing_queue_status(result_id);
CREATE INDEX idx_queue_status_created ON processing_queue_status(created_at DESC);

COMMENT ON TABLE processing_queue_status IS 'Estado de procesamiento de mensajes SQS';

-- ============================================
-- FUNCIONES: Triggers para updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Aplicar a tablas relevantes
CREATE TRIGGER update_patients_updated_at 
    BEFORE UPDATE ON patients
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lab_results_updated_at 
    BEFORE UPDATE ON lab_results
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_queue_status_updated_at 
    BEFORE UPDATE ON processing_queue_status
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCIONES: Audit Logging
-- ============================================

CREATE OR REPLACE FUNCTION audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (
            event_type, table_name, record_id, old_values
        ) VALUES (
            'DELETE', TG_TABLE_NAME, OLD.id::TEXT, row_to_json(OLD)
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (
            event_type, table_name, record_id, old_values, new_values
        ) VALUES (
            'UPDATE', TG_TABLE_NAME, NEW.id::TEXT, 
            row_to_json(OLD), row_to_json(NEW)
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (
            event_type, table_name, record_id, new_values
        ) VALUES (
            'INSERT', TG_TABLE_NAME, NEW.id::TEXT, row_to_json(NEW)
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Aplicar audit logging (comentado por defecto, puede generar MUCHOS logs)
-- CREATE TRIGGER audit_lab_results 
--     AFTER INSERT OR UPDATE OR DELETE ON lab_results
--     FOR EACH ROW 
--     EXECUTE FUNCTION audit_changes();

-- ============================================
-- VISTAS: Queries comunes
-- ============================================

-- Vista: Resultados completos con valores
CREATE OR REPLACE VIEW v_complete_results AS
SELECT 
    lr.result_id,
    lr.patient_id,
    p.first_name,
    p.last_name,
    p.email,
    lr.lab_name,
    lr.test_type,
    lr.test_date,
    lr.status,
    lr.physician_name,
    json_agg(
        json_build_object(
            'test_code', tv.test_code,
            'test_name', tv.test_name,
            'value', tv.value,
            'unit', tv.unit,
            'reference_range', tv.reference_range,
            'is_abnormal', tv.is_abnormal,
            'severity', tv.severity
        ) ORDER BY tv.test_code
    ) as test_values,
    lr.created_at,
    lr.updated_at
FROM lab_results lr
JOIN patients p ON lr.patient_id = p.patient_id
LEFT JOIN test_values tv ON lr.result_id = tv.result_id
WHERE p.deleted_at IS NULL
GROUP BY lr.result_id, p.patient_id, p.first_name, p.last_name, p.email;

COMMENT ON VIEW v_complete_results IS 'Vista consolidada de resultados con valores';

-- Vista: Dashboard de pacientes
CREATE OR REPLACE VIEW v_patient_dashboard AS
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    p.email,
    COUNT(DISTINCT lr.result_id) as total_results,
    COUNT(DISTINCT lr.result_id) FILTER (WHERE lr.status = 'completed') as completed_results,
    COUNT(DISTINCT lr.result_id) FILTER (WHERE lr.status = 'pending') as pending_results,
    MAX(lr.test_date) as last_test_date,
    COUNT(DISTINCT tv.id) FILTER (WHERE tv.is_abnormal = TRUE) as abnormal_values_count
FROM patients p
LEFT JOIN lab_results lr ON p.patient_id = lr.patient_id
LEFT JOIN test_values tv ON lr.result_id = tv.result_id
WHERE p.deleted_at IS NULL
GROUP BY p.patient_id;

COMMENT ON VIEW v_patient_dashboard IS 'Dashboard summary para cada paciente';

-- ============================================
-- DATOS DE EJEMPLO (Solo para desarrollo)
-- ============================================

-- Insertar pacientes de ejemplo
INSERT INTO patients (patient_id, first_name, last_name, date_of_birth, email, phone)
VALUES 
    ('P123456', 'John', 'Smith', '1985-03-15', 'john.smith@example.com', '+1-555-0101'),
    ('P234567', 'Maria', 'Garcia', '1990-07-22', 'maria.garcia@example.com', '+1-555-0102'),
    ('P345678', 'James', 'Wilson', '1978-11-08', 'james.wilson@example.com', '+1-555-0103')
ON CONFLICT (patient_id) DO NOTHING;

-- ============================================
-- FUNCIONES ÚTILES
-- ============================================

-- Función: Limpiar datos viejos
CREATE OR REPLACE FUNCTION cleanup_old_data(days_old INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- Archivar resultados viejos
    UPDATE lab_results 
    SET status = 'archived'
    WHERE test_date < CURRENT_DATE - INTERVAL '1 day' * days_old
    AND status = 'completed';
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    RETURN rows_affected;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_data IS 'Archiva resultados más viejos que X días';

-- Función: Estadísticas de procesamiento
CREATE OR REPLACE FUNCTION get_processing_stats(start_date DATE DEFAULT CURRENT_DATE - 7)
RETURNS TABLE (
    date DATE,
    total_processed INTEGER,
    avg_processing_time_seconds NUMERIC,
    failed_count INTEGER,
    success_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(lr.created_at) as date,
        COUNT(*)::INTEGER as total_processed,
        ROUND(AVG(EXTRACT(EPOCH FROM (lr.processing_completed_at - lr.processing_started_at))), 2) as avg_processing_time_seconds,
        COUNT(*) FILTER (WHERE lr.status = 'failed')::INTEGER as failed_count,
        ROUND(
            (COUNT(*) FILTER (WHERE lr.status = 'completed')::NUMERIC / COUNT(*)::NUMERIC) * 100, 
            2
        ) as success_rate
    FROM lab_results lr
    WHERE DATE(lr.created_at) >= start_date
    GROUP BY DATE(lr.created_at)
    ORDER BY date DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_processing_stats IS 'Estadísticas de procesamiento por día';

-- ============================================
-- PERMISOS (ajustar según roles)
-- ============================================

-- Crear rol de solo lectura (para reporting)
-- CREATE ROLE healthcare_readonly;
-- GRANT CONNECT ON DATABASE healthcaredb TO healthcare_readonly;
-- GRANT USAGE ON SCHEMA public TO healthcare_readonly;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO healthcare_readonly;

-- Crear rol de aplicación (read/write limitado)
-- CREATE ROLE healthcare_app;
-- GRANT CONNECT ON DATABASE healthcaredb TO healthcare_app;
-- GRANT USAGE ON SCHEMA public TO healthcare_app;
-- GRANT SELECT, INSERT, UPDATE ON patients, lab_results, test_values TO healthcare_app;
-- GRANT SELECT, INSERT, UPDATE ON processing_queue_status TO healthcare_app;
-- GRANT SELECT ON audit_log TO healthcare_app;


-- VACUUM Y ANALYZE

-- Optimizar tablas
VACUUM ANALYZE patients;
VACUUM ANALYZE lab_results;
VACUUM ANALYZE test_values;
VACUUM ANALYZE audit_log;
