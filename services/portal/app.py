
#!/usr/bin/env python3
# ========================================
# FILE: services/portal/app.py
# Healthcare Lab Results Portal (Paciente)
# ========================================

from flask import Flask, render_template_string, jsonify, request, redirect, session, url_for
from flask import redirect, url_for, current_app
from urllib.parse import urlencode
import psycopg2
import os
import json
import boto3
import requests
from datetime import datetime
from functools import wraps
from jose import jwt


app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'your-secret-key-change-in-production')

# Environment variables - Database
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# Environment variables - Cognito
COGNITO_DOMAIN = os.environ.get('COGNITO_DOMAIN')
COGNITO_CLIENT_ID = os.environ.get('COGNITO_CLIENT_ID')
COGNITO_USER_POOL_ID = os.environ.get('COGNITO_USER_POOL_ID')
COGNITO_REGION = os.environ.get('COGNITO_REGION', 'us-east-1')

# URL pública del portal (la de CloudFront / ALB)
APP_URL = os.environ.get('APP_URL', 'http://localhost:3000')

# URL a la que Cognito redirige después del logout
LOGOUT_URL = os.environ.get('LOGOUT_URL', APP_URL)

PDF_LAMBDA_NAME = os.environ.get("PDF_LAMBDA_NAME")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

lambda_client = boto3.client("lambda", region_name=AWS_REGION)





# ======================================================
# DB helper
# ======================================================
def get_db_connection():
    """Create database connection (usa el schema que ya creaste con schema.sql)."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )


# ======================================================
# AUTH helpers
# ======================================================
def login_required(f):
    """Protege rutas, requiere que exista session['user']"""

    @wraps(f)
    def decorated_function(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("login"))
        return f(*args, **kwargs)

    return decorated_function


def get_user_email_from_token():
    """Extrae email del ID token de Cognito (sin verificación fuerte)."""
    try:
        id_token = session["user"]["id_token"]
        claims = jwt.get_unverified_claims(id_token)
        return claims.get("email", "")
    except Exception as e:
        print(f"Error extracting email from token: {e}")
        return ""


def get_user_name_from_token():
    """Extrae nombre del ID token de Cognito."""
    try:
        id_token = session["user"]["id_token"]
        claims = jwt.get_unverified_claims(id_token)

        name = claims.get("name", "")
        if not name:
            name = claims.get("given_name", "")
        if not name:
            email = claims.get("email", "User")
            name = email.split("@")[0]
        return name
    except Exception as e:
        print(f"Error extracting name from token: {e}")
        return "User"


# ======================================================
# TEMPLATES (login, dashboard, result detail)
# ======================================================
# --- LOGIN_TEMPLATE (idéntico al que ya tenías) ---
LOGIN_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Healthcare Lab Portal</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --primary: #0d9488;
            --primary-hover: #0f766e;
            --background: #0a0a0a;
            --card: #141414;
            --card-border: #262626;
            --text: #fafafa;
            --text-muted: #a1a1aa;
            --accent: #14b8a6;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--background);
            min-height: 100vh;
            display: flex;
            color: var(--text);
        }
        
        .login-wrapper {
            display: flex;
            width: 100%;
            min-height: 100vh;
        }
        
        .login-left {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 40px;
        }
        
        .login-right {
            flex: 1;
            background: linear-gradient(135deg, var(--primary) 0%, #047857 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 40px;
            position: relative;
            overflow: hidden;
        }
        
        .login-right::before {
            content: '';
            position: absolute;
            width: 600px;
            height: 600px;
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 50%;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
        }
        
        .login-right::after {
            content: '';
            position: absolute;
            width: 400px;
            height: 400px;
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 50%;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
        }
        
        .login-container {
            max-width: 400px;
            width: 100%;
        }
        
        .logo {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 48px;
        }
        
        .logo-icon {
            width: 48px;
            height: 48px;
            background: var(--primary);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .logo-icon svg {
            width: 28px;
            height: 28px;
            color: white;
        }
        
        .logo-text {
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text);
        }
        
        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 12px;
            line-height: 1.2;
        }
        
        .subtitle {
            color: var(--text-muted);
            font-size: 1.1rem;
            margin-bottom: 40px;
            line-height: 1.6;
        }
        
        .btn-login {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            width: 100%;
            background: var(--primary);
            color: white;
            padding: 16px 32px;
            border: none;
            border-radius: 12px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.2s ease;
        }
        
        .btn-login:hover {
            background: var(--primary-hover);
            transform: translateY(-2px);
            box-shadow: 0 10px 40px rgba(13, 148, 136, 0.3);
        }
        
        .btn-login svg {
            width: 20px;
            height: 20px;
        }
        
        .features {
            margin-top: 48px;
            padding-top: 32px;
            border-top: 1px solid var(--card-border);
        }
        
        .feature {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
            color: var(--text-muted);
            font-size: 0.95rem;
        }
        
        .feature svg {
            width: 20px;
            height: 20px;
            color: var(--accent);
            flex-shrink: 0;
        }
        
        .right-content {
            position: relative;
            z-index: 1;
            text-align: center;
            color: white;
        }
        
        .right-content h2 {
            font-size: 2rem;
            font-weight: 700;
            margin-bottom: 16px;
        }
        
        .right-content p {
            font-size: 1.1rem;
            opacity: 0.9;
            max-width: 400px;
            line-height: 1.6;
        }
        
        .stats-preview {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-top: 40px;
        }
        
        .stat-item {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            padding: 20px;
            border-radius: 12px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        
        .stat-item h3 {
            font-size: 1.5rem;
            font-weight: 700;
        }
        
        .stat-item p {
            font-size: 0.85rem;
            opacity: 0.8;
            margin-top: 4px;
        }
        
        @media (max-width: 1024px) {
            .login-right {
                display: none;
            }
        }
        
        @media (max-width: 480px) {
            .login-left {
                padding: 24px;
            }
            
            h1 {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body>
    <div class="login-wrapper">
        <div class="login-left">
            <div class="login-container">
                <div class="logo">
                    <div class="logo-icon">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                        </svg>
                    </div>
                    <span class="logo-text">LabPortal</span>
                </div>
                
                <h1>Welcome back</h1>
                <p class="subtitle">Sign in to access patient lab results and manage healthcare data securely.</p>
                
                <a href="{{ cognito_login_url }}" class="btn-login">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                    </svg>
                    Sign in with Cognito
                </a>
                
                <div class="features">
                    <div class="feature">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                        </svg>
                        <span>HIPAA Compliant & Secure</span>
                    </div>
                    <div class="feature">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                        <span>Real-time lab results access</span>
                    </div>
                    <div class="feature">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 012 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                        <span>Complete patient management</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="login-right">
            <div class="right-content">
                <h2>Healthcare Lab Portal</h2>
                <p>Streamlined access to laboratory results with enterprise-grade security and compliance.</p>
                <div class="stats-preview">
                    <div class="stat-item">
                        <h3>99.9%</h3>
                        <p>Uptime</p>
                    </div>
                    <div class="stat-item">
                        <h3>256-bit</h3>
                        <p>Encryption</p>
                    </div>
                    <div class="stat-item">
                        <h3>24/7</h3>
                        <p>Support</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"""

# --- DASHBOARD_TEMPLATE (idéntico al tuyo pero con un pequeño cambio en result_id) ---
DASHBOARD_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Healthcare Lab Portal</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --primary: #0d9488;
            --primary-hover: #0f766e;
            --background: #0a0a0a;
            --card: #141414;
            --card-border: #262626;
            --text: #fafafa;
            --text-muted: #a1a1aa;
            --accent: #14b8a6;
            --success: #22c55e;
            --warning: #f59e0b;
            --danger: #ef4444;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--background);
            min-height: 100vh;
            color: var(--text);
        }
        
        .navbar {
            background: var(--card);
            border-bottom: 1px solid var(--card-border);
            padding: 16px 32px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        
        .nav-left {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .logo-icon {
            width: 40px;
            height: 40px;
            background: var(--primary);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .logo-icon svg {
            width: 24px;
            height: 24px;
            color: white;
        }
        
        .logo-text {
            font-size: 1.25rem;
            font-weight: 700;
            color: var(--text);
        }
        
        .nav-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .user-info {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 8px 16px;
            background: var(--background);
            border-radius: 8px;
            border: 1px solid var(--card-border);
        }

        .user-meta {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .user-name {
            font-size: 0.9rem;
            font-weight: 500;
        }

        .user-id {
            font-size: 0.75rem;
            color: var(--text-muted);
        }

        
        .user-avatar {
            width: 32px;
            height: 32px;
            background: var(--primary);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            font-size: 0.875rem;
        }
        
        .btn-logout {
            display: flex;
            align-items: center;
            gap: 8px;
            background: transparent;
            color: var(--text-muted);
            padding: 10px 16px;
            border: 1px solid var(--card-border);
            border-radius: 8px;
            cursor: pointer;
            text-decoration: none;
            font-size: 0.875rem;
            font-weight: 500;
            transition: all 0.2s;
        }
        
        .btn-logout:hover {
            background: var(--danger);
            color: white;
            border-color: var(--danger);
        }
        
        .btn-logout svg {
            width: 18px;
            height: 18px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 32px;
        }
        
        .page-header {
            margin-bottom: 32px;
        }
        
        .page-header h1 {
            font-size: 1.875rem;
            font-weight: 700;
            margin-bottom: 8px;
        }
        
        .page-header p {
            color: var(--text-muted);
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 24px;
            margin-bottom: 32px;
        }
        
        .stat-card {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 24px;
            transition: all 0.2s;
        }
        
        .stat-card:hover {
            border-color: var(--primary);
            transform: translateY(-2px);
        }
        
        .stat-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 16px;
        }
        
        .stat-icon {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .stat-icon.primary {
            background: rgba(13, 148, 136, 0.15);
            color: var(--accent);
        }
        
        .stat-icon.success {
            background: rgba(34, 197, 94, 0.15);
            color: var(--success);
        }
        
        .stat-icon.warning {
            background: rgba(245, 158, 11, 0.15);
            color: var(--warning);
        }
        
        .stat-icon svg {
            width: 24px;
            height: 24px;
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--text);
            line-height: 1;
        }
        
        .stat-label {
            color: var(--text-muted);
            font-size: 0.875rem;
            margin-top: 8px;
        }
        
        .results-section {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            overflow: hidden;
        }
        
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 24px;
            border-bottom: 1px solid var(--card-border);
        }
        
        .section-header h2 {
            font-size: 1.25rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .section-header h2 svg {
            width: 24px;
            height: 24px;
            color: var(--accent);
        }
        
        .table-container {
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th {
            text-align: left;
            padding: 16px 24px;
            background: var(--background);
            color: var(--text-muted);
            font-weight: 500;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--card-border);
        }
        
        td {
            padding: 16px 24px;
            border-bottom: 1px solid var(--card-border);
            font-size: 0.875rem;
        }
        
        tr:hover td {
            background: rgba(255,255,255,0.02);
        }
        
        tr:last-child td {
            border-bottom: none;
        }
        
        .result-id {
            font-family: 'SF Mono', 'Monaco', monospace;
            color: var(--text-muted);
            font-size: 0.8rem;
        }
        
        .patient-info {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }
        
        .patient-name {
            font-weight: 500;
            color: var(--text);
        }
        
        .patient-email {
            color: var(--text-muted);
            font-size: 0.8rem;
        }
        
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.03em;
        }
        
        .status-badge::before {
            content: '';
            width: 6px;
            height: 6px;
            border-radius: 50%;
        }
        
        .status-ready {
            background: rgba(34, 197, 94, 0.15);
            color: var(--success);
        }
        
        .status-ready::before {
            background: var(--success);
        }
        
        .status-pending {
            background: rgba(245, 158, 11, 0.15);
            color: var(--warning);
        }
        
        .status-pending::before {
            background: var(--warning);
        }
        
        .btn-view {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: var(--primary);
            color: white;
            padding: 8px 16px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            text-decoration: none;
            font-size: 0.8rem;
            font-weight: 500;
            transition: all 0.2s;
        }
        
        .btn-view:hover {
            background: var(--primary-hover);
            transform: translateY(-1px);
        }
        
        .btn-view svg {
            width: 16px;
            height: 16px;
        }
        
        .empty-state {
            text-align: center;
            padding: 64px 24px;
            color: var(--text-muted);
        }
        
        .empty-state svg {
            width: 64px;
            height: 64px;
            margin-bottom: 16px;
            opacity: 0.5;
        }
        
        .empty-state h3 {
            font-size: 1.125rem;
            font-weight: 600;
            margin-bottom: 8px;
            color: var(--text);
        }
        
        @media (max-width: 768px) {
            .navbar {
                padding: 12px 16px;
            }
            
            .container {
                padding: 16px;
            }
            
            .user-info {
                display: none;
            }
            
            .stats-grid {
                grid-template-columns: 1fr;
            }
            
            th, td {
                padding: 12px 16px;
            }
            
            .patient-email {
                display: none;
            }
        }
    </style>
</head>
<body>
    <nav class="navbar">
        <div class="nav-left">
            <div class="logo-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                </svg>
            </div>
            <span class="logo-text">LabPortal</span>
        </div>
        <div class="nav-right">
            <div class="user-info">
                <div class="user-avatar">{{ user_name[0]|upper }}</div>
                <div class="user-meta">
                    <div class="user-name">{{ user_name }}</div>
                    {% if patient_id %}
                    <div class="user-id">Patient ID: {{ patient_id }}</div>
                    {% endif %}
                </div>
            </div>
            <a href="/logout" class="btn-logout">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
                Logout
            </a>
        </div>
    </nav>
    
    <main class="container">
        <div class="page-header">
            <h1>Dashboard</h1>
            <p>Overview of lab results and patient data</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon primary">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                    </div>
                </div>
                <div class="stat-value">{{ total_results }}</div>
                <div class="stat-label">Total Results</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon success">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                        </svg>
                    </div>
                </div>
                <div class="stat-value">{{ total_patients }}</div>
                <div class="stat-label">Total Patients</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon warning">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                    </div>
                </div>
                <div class="stat-value">{{ pending_results }}</div>
                <div class="stat-label">Pending Results</div>
            </div>
        </div>
        
        <div class="results-section">
            <div class="section-header">
                <h2>
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 012 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                    </svg>
                    Recent Lab Results
                </h2>
            </div>
            
            {% if results %}
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Result ID</th>
                            <th>Patient</th>
                            <th>Date</th>
                            <th>Status</th>
                            <th>ownload</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for result in results %}
                        <tr>
                            <!-- result[0] ahora es INTEGER, lo mostramos completo -->
                            <td><span class="result-id">#{{ result[0] }}</span></td>
                            <td>
                                <div class="patient-info">
                                    <span class="patient-name">{{ result[1] }}</span>
                                    <span class="patient-email">{{ result[2] }}</span>
                                </div>
                            </td>
                            <td>{{ result[3].strftime('%b %d, %Y') }}</td>
                            <td><span class="status-badge status-{{ result[4] }}">{{ result[4] }}</span></td>
                            <td>
                                <a href="/results/{{ result[0] }}/download" class="btn-view">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2" />
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M7 10l5 5 5-5M12 4v11" />
                                    </svg>
                                    Download
                                </a>
                            </td>

                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
            {% else %}
            <div class="empty-state">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3>No results available</h3>
                <p>Lab results will appear here once they are processed.</p>
            </div>
            {% endif %}
        </div>
    </main>
</body>
</html>
"""

# --- RESULT_DETAIL_TEMPLATE (igual que el tuyo, lo reutilizamos mostrando un JSON con test_values) ---
RESULT_DETAIL_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lab Result Details - Healthcare Lab Portal</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --primary: #0d9488;
            --primary-hover: #0f766e;
            --background: #0a0a0a;
            --card: #141414;
            --card-border: #262626;
            --text: #fafafa;
            --text-muted: #a1a1aa;
            --accent: #14b8a6;
            --success: #22c55e;
            --warning: #f59e0b;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--background);
            min-height: 100vh;
            color: var(--text);
        }
        
        .navbar {
            background: var(--card);
            border-bottom: 1px solid var(--card-border);
            padding: 16px 32px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        
        .nav-left {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .logo-icon {
            width: 40px;
            height: 40px;
            background: var(--primary);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .logo-icon svg {
            width: 24px;
            height: 24px;
            color: white;
        }
        
        .logo-text {
            font-size: 1.25rem;
            font-weight: 700;
            color: var(--text);
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
            padding: 32px;
        }
        
        .back-link {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            color: var(--text-muted);
            text-decoration: none;
            font-size: 0.875rem;
            margin-bottom: 24px;
            transition: color 0.2s;
        }
        
        .back-link:hover {
            color: var(--accent);
        }
        
        .back-link svg {
            width: 18px;
            height: 18px;
        }
        
        .page-header {
            margin-bottom: 32px;
        }
        
        .page-header h1 {
            font-size: 1.875rem;
            font-weight: 700;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .page-header h1 svg {
            width: 32px;
            height: 32px;
            color: var(--accent);
        }
        
        .detail-card {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            overflow: hidden;
            margin-bottom: 24px;
        }
        
        .card-header {
            padding: 20px 24px;
            border-bottom: 1px solid var(--card-border);
            background: var(--background);
        }
        
        .card-header h2 {
            font-size: 1rem;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        
        .card-body {
            padding: 24px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 24px;
        }
        
        .info-item {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        
        .info-label {
            font-size: 0.75rem;
            font-weight: 500;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        
        .info-value {
            font-size: 1rem;
            color: var(--text);
            font-weight: 500;
        }
        
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            width: fit-content;
        }
        
        .status-badge::before {
            content: '';
            width: 6px;
            height: 6px;
            border-radius: 50%;
        }
        
        .status-ready {
            background: rgba(34, 197, 94, 0.15);
            color: var(--success);
        }
        
        .status-ready::before {
            background: var(--success);
        }
        
        .status-pending {
            background: rgba(245, 158, 11, 0.15);
            color: var(--warning);
        }
        
        .status-pending::before {
            background: var(--warning);
        }
        
        .json-container {
            background: var(--background);
            border-radius: 12px;
            padding: 20px;
            overflow-x: auto;
        }
        
        .json-container pre {
            font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
            font-size: 0.85rem;
            line-height: 1.6;
            color: var(--accent);
            margin: 0;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        @media (max-width: 768px) {
            .navbar {
                padding: 12px 16px;
            }
            
            .container {
                padding: 16px;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <nav class="navbar">
        <div class="nav-left">
            <div class="logo-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                </svg>
            </div>
            <span class="logo-text">LabPortal</span>
        </div>
    </nav>
    
    <main class="container">
        <a href="/" class="back-link">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to Dashboard
        </a>
        
        <div class="page-header">
            <h1>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Lab Result Details
            </h1>
        </div>
        
        <div class="detail-card">
            <div class="card-header">
                <h2>Patient Information</h2>
            </div>
            <div class="card-body">
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-label">Patient Name</span>
                        <span class="info-value">{{ patient_name }}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Email</span>
                        <span class="info-value">{{ patient_email }}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Date</span>
                        <span class="info-value">{{ created_at }}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Status</span>
                        <span class="status-badge status-{{ status }}">{{ status }}</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="detail-card">
            <div class="card-header">
                <h2>Lab Data</h2>
            </div>
            <div class="card-body">
                <div class="json-container">
                    <pre>{{ lab_data_json }}</pre>
                </div>
            </div>
        </div>
    </main>
</body>
</html>
"""


# ======================================================
# ROUTES
# ======================================================
@app.route('/login')
def login():
    """Show login page"""
    cognito_login_url = (
        f"https://{COGNITO_DOMAIN}/login"
        f"?client_id={COGNITO_CLIENT_ID}"
        f"&response_type=code"
        f"&redirect_uri={APP_URL}/callback"
    )
    return render_template_string(LOGIN_TEMPLATE, cognito_login_url=cognito_login_url)


@app.route('/callback')
def callback():
    """Handle Cognito callback"""
    code = request.args.get('code')

    if not code:
        return "Error: No authorization code", 400

    token_url = f"https://{COGNITO_DOMAIN}/oauth2/token"
    data = {
        "grant_type": "authorization_code",
        "client_id": COGNITO_CLIENT_ID,
        "code": code,
        "redirect_uri": f"{APP_URL}/callback",
    }

    try:
        response = requests.post(token_url, data=data)
        tokens = response.json()

        if 'id_token' in tokens:
            id_token = tokens['id_token']
            session['user'] = {'id_token': id_token, 'authenticated': True}
            return redirect(url_for('index'))
        else:
            return f"Error getting tokens: {tokens}", 400
    except Exception as e:
        return f"Error: {str(e)}", 500



@app.route("/logout")
def logout():
    session.clear()

    params = {
        "client_id": COGNITO_CLIENT_ID,
        "logout_uri": LOGOUT_URL,  # ej: https://d2z9bd17xif50.cloudfront.net
    }

    # COGNITO_DOMAIN viene SIN protocolo, así que le agregamos https://
    url = f"https://{COGNITO_DOMAIN}/logout?{urlencode(params)}"
    return redirect(url)

@app.route("/")
@login_required
def index():
    """Dashboard principal PARA EL PACIENTE LOGUEADO (filtrado por email)."""
    try:
        user_email = get_user_email_from_token()
        user_name = get_user_name_from_token()

        if not user_email:
            return redirect(url_for("logout"))

        conn = get_db_connection()
        cursor = conn.cursor()

        # Obtener patient_id del paciente logueado
        cursor.execute(
            """
            SELECT patient_id
            FROM patients
            WHERE email = %s
            """,
            (user_email,),
        )
        row = cursor.fetchone()
        patient_id = row[0] if row else None

        # Stats usando la vista v_patient_dashboard
        cursor.execute(
            """
            SELECT total_results, pending_results
            FROM v_patient_dashboard
            WHERE email = %s
        """,
            (user_email,),
        )
        row = cursor.fetchone()
        if row:
            total_results, pending_results = row
        else:
            total_results, pending_results = 0, 0

        total_patients = 1 if total_results > 0 else 0

        # Últimos resultados de este paciente
        cursor.execute(
            """
            SELECT
                lr.result_id,
                p.first_name || ' ' || p.last_name AS full_name,
                p.email,
                lr.test_date,
                lr.status
            FROM lab_results lr
            JOIN patients p ON lr.patient_id = p.patient_id
            WHERE p.email = %s
            ORDER BY lr.test_date DESC
            LIMIT 20
        """,
            (user_email,),
        )
        results = cursor.fetchall()

        cursor.close()
        conn.close()

        return render_template_string(
            DASHBOARD_TEMPLATE,
            total_results=total_results,
            total_patients=total_patients,
            pending_results=pending_results,
            results=results,
            user_name=user_name,
            user_email=user_email,
            patient_id=patient_id,
        )
    except Exception as e:
        return f"<h1>Error</h1><p>{str(e)}</p>", 500


@app.route("/health")
def health():
    """Health check endpoint."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        return jsonify({"status": "healthy"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500


@app.route("/results/<int:result_id>")
@login_required
def result_detail(result_id):
    """Detalle de un resultado, asegurando que pertenece al paciente logueado."""
    try:
        user_email = get_user_email_from_token()
        if not user_email:
            return redirect(url_for("logout"))

        conn = get_db_connection()
        cursor = conn.cursor()

        # Datos generales del resultado
        cursor.execute(
            """
            SELECT
                lr.result_id,
                p.first_name,
                p.last_name,
                p.email,
                lr.lab_name,
                lr.test_type,
                lr.test_date,
                lr.status,
                lr.physician_name
            FROM lab_results lr
            JOIN patients p ON lr.patient_id = p.patient_id
            WHERE lr.result_id = %s
              AND p.email = %s
        """,
            (result_id, user_email),
        )
        row = cursor.fetchone()

        if not row:
            cursor.close()
            conn.close()
            return (
                """
                <h1 style="color: #ef4444;">Access Denied</h1>
                <p>You don't have permission to view this result, or it doesn't exist.</p>
                <a href="/" style="color: #14b8a6;">← Back to Dashboard</a>
                """,
                403,
            )

        (
            _r_id,
            first_name,
            last_name,
            email,
            lab_name,
            test_type,
            test_date,
            status,
            physician_name,
        ) = row

        # Valores individuales de la prueba
        cursor.execute(
            """
            SELECT
                test_code,
                test_name,
                value,
                unit,
                reference_range,
                is_abnormal,
                severity
            FROM test_values
            WHERE result_id = %s
            ORDER BY test_code
        """,
            (result_id,),
        )
        rows = cursor.fetchall()

        cursor.close()
        conn.close()

        lab_data = [
            {
                "test_code": r[0],
                "test_name": r[1],
                "value": float(r[2]) if r[2] is not None else None,
                "unit": r[3],
                "reference_range": r[4],
                "is_abnormal": r[5],
                "severity": r[6],
            }
            for r in rows
        ]

        return render_template_string(
            RESULT_DETAIL_TEMPLATE,
            patient_name=f"{first_name} {last_name}",
            patient_email=email,
            created_at=test_date.strftime("%B %d, %Y at %H:%M"),
            status=status,
            lab_data_json=json.dumps(lab_data, indent=2),
        )
    except Exception as e:
        return f"<h1>Error</h1><p>{str(e)}</p>", 500

@app.route("/results/<int:result_id>/download")
@login_required
def result_download(result_id):
    """
    Valida que el resultado pertenece al paciente logueado
    Invoca la Lambda PDF y redirige a la signed URL
    """
    try:
        user_email = get_user_email_from_token()
        if not user_email:
            return redirect(url_for("logout"))

        # Validar que el resultado es del usuario logueado
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT lr.result_id
            FROM lab_results lr
            JOIN patients p ON lr.patient_id = p.patient_id
            WHERE lr.result_id = %s
              AND p.email = %s
            """,
            (result_id, user_email),
        )
        row = cursor.fetchone()
        cursor.close()
        conn.close()

        if not row:
            return ("You don't have permission to download this result.", 403)

        if not PDF_LAMBDA_NAME:
            return (
                "PDF_LAMBDA_NAME is not configured in the environment.",
                500,
            )

        # Invocar la Lambda para generar el PDF y obtener la signed URL
        lambda_payload = {"result_id": result_id}

        response = lambda_client.invoke(
            FunctionName=PDF_LAMBDA_NAME,
            InvocationType="RequestResponse",
            Payload=json.dumps(lambda_payload).encode("utf-8"),
        )

        raw_payload = response["Payload"].read()
        lambda_result = json.loads(raw_payload or "{}")

        status_code = lambda_result.get("statusCode", 500)
        if status_code != 200:
            # devolvemos el cuerpo de la lambda (error) para debug
            return (
                f"Error generating PDF (Lambda status {status_code}): "
                f"{lambda_result.get('body')}",
                500,
            )

        body = json.loads(lambda_result.get("body", "{}"))
        signed_url = body.get("signed_url")

        if not signed_url:
            return (
                "PDF service did not return a signed_url.",
                500,
            )

        # Redirigimos al navegador directamente a la signed URL de S3
        return redirect(signed_url)

    except Exception as e:
        current_app.logger.exception("Error generating/downloading PDF")
        return (f"Unexpected error generating PDF: {str(e)}", 500)

# ======================================================
# MAIN
# ======================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
