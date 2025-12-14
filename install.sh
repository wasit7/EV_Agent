#!/bin/bash

# EV Rental Agent - Master Installer
# Version 1.4: Explicit Appointment Date vs Creation Date

PROJECT_ROOT="ev_rental_project"

echo "🚀 Starting Master Install for: $PROJECT_ROOT"

# --- STEP 1: Create Directory Structure ---
echo "📂 Creating directory structure..."
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

mkdir -p config
mkdir -p ev_app/migrations
mkdir -p ev_app/management/commands
mkdir -p templates
mkdir -p static/js
mkdir -p data

# --- STEP 2: Generate Configuration Files ---

echo "📝 Generating Dockerfile..."
cat > Dockerfile <<EOF
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
WORKDIR /app

RUN apt-get update && apt-get install -y netcat-openbsd gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . /app/
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
EOF

echo "📝 Generating docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.7'

services:
  web:
    build: .
    container_name: ev_agent_web
    volumes:
      - .:/app
      - ./data:/app/data
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      - db
    command: sh entrypoint.sh

  db:
    image: postgres:16
    container_name: ev_agent_db
    volumes:
      - pg_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ev_app
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password

volumes:
  pg_data:
EOF

echo "📝 Generating requirements.txt..."
cat > requirements.txt <<EOF
Django>=5.0,<6.0
psycopg2-binary
dspy-ai
google-generativeai
python-dotenv
EOF

echo "📝 Generating .env placeholder..."
cat > .env <<EOF
DEBUG=True
SECRET_KEY=django-insecure-master-key-change-in-prod
DATABASE_URL=postgres://postgres:password@db:5432/ev_app
ALLOWED_HOSTS=*
# REPLACE THIS WITH YOUR REAL KEY
GEMINI_API_KEY=
EOF

echo "📝 Generating entrypoint.sh..."
cat > entrypoint.sh <<EOF
#!/bin/sh

echo "Waiting for postgres..."
while ! nc -z db 5432; do
  sleep 0.1
done
echo "PostgreSQL started"

echo "Applying database migrations..."
python manage.py makemigrations ev_app
python manage.py migrate

echo "Loading inventory data..."
python manage.py load_inventory

echo "Starting server..."
exec python manage.py runserver 0.0.0.0:8000
EOF
chmod +x entrypoint.sh

# --- STEP 3: Generate Application Code ---

echo "📝 Populating manage.py..."
cat > manage.py <<'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
EOF
chmod +x manage.py

echo "📝 Populating config files..."
touch config/__init__.py

cat > config/wsgi.py <<'EOF'
# config/wsgi.py
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
application = get_wsgi_application()
EOF

cat > config/settings.py <<'EOF'
# config/settings.py
from pathlib import Path
import os
import dspy

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-test-key')
DEBUG = os.environ.get('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'ev_app',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_DB', 'ev_app'),
        'USER': os.environ.get('POSTGRES_USER', 'postgres'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD', 'password'),
        'HOST': 'db',
        'PORT': '5432',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATICFILES_DIRS = [BASE_DIR / "static"]
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# DSPy Config
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY:
    lm = dspy.LM('gemini/gemini-2.5-flash-preview-09-2025', api_key=GEMINI_API_KEY)
    dspy.configure(lm=lm)
else:
    print("WARNING: GEMINI_API_KEY not found in environment variables.")
EOF

cat > config/urls.py <<'EOF'
# config/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('ev_app.urls')),
]
EOF

echo "📝 Populating ev_app files..."
touch ev_app/__init__.py

cat > ev_app/models.py <<'EOF'
# ev_app/models.py
from django.db import models
from django.contrib.auth.models import User

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    full_name = models.CharField(max_length=100, blank=True, null=True)
    nickname = models.CharField(max_length=50, blank=True, null=True)
    license_id = models.CharField(max_length=50, blank=True, null=True)
    phone = models.CharField(max_length=20, blank=True, null=True)

    def __str__(self):
        name = self.full_name or self.user.username
        return f"{name} (Nick: {self.nickname}) (License: {self.license_id})"

class EVCar(models.Model):
    STATUS_CHOICES = [
        ('AVAILABLE', 'Available'),
        ('RENTED', 'Rented'),
        ('MAINTENANCE', 'Maintenance'),
    ]
    model_name = models.CharField(max_length=100)
    range_km = models.IntegerField()
    price_per_day = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='AVAILABLE')

    def __str__(self):
        return f"{self.model_name} ({self.status})"

class Transaction(models.Model):
    TYPE_CHOICES = [('TEST_DRIVE', 'Test Drive'), ('PURCHASE', 'Purchase')]
    STATUS_CHOICES = [('DRAFT', 'Draft'), ('CONFIRMED', 'Confirmed'), ('CANCELLED', 'Cancelled')]

    customer = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    car = models.ForeignKey(EVCar, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    
    # --- Date Fields Requirement Met Here ---
    appointment_date = models.DateTimeField(null=True, blank=True) # For appointment/deliverable
    created_at = models.DateTimeField(auto_now_add=True)           # For record creation
    # ----------------------------------------

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')

    def __str__(self):
        return f"{self.get_type_display()} - {self.car.model_name} ({self.status})"
EOF

cat > ev_app/dspy_agent.py <<'EOF'
# ev_app/dspy_agent.py
import dspy
from django.utils import timezone
from .models import UserProfile, EVCar, Transaction
from django.contrib.auth.models import User
import json

def onboard_user(user_id: int, full_name: str, nickname: str, license_id: str, phone: str = "") -> str:
    """Updates user profile. Requires Full Name, Nickname, and License ID."""
    try:
        user = User.objects.get(id=user_id)
        profile, created = UserProfile.objects.get_or_create(user=user)
        profile.full_name = full_name
        profile.nickname = nickname
        profile.license_id = license_id
        if phone: profile.phone = phone
        profile.save()
        return f"User {full_name} (Nickname: {nickname}) onboarded successfully with License ID: {license_id}."
    except User.DoesNotExist:
        return "Error: User not found."

def search_cars(query_str: str = "") -> str:
    """Searches for available EV cars based on model name or general availability."""
    cars = EVCar.objects.filter(status='AVAILABLE')
    if query_str: cars = cars.filter(model_name__icontains=query_str)
    if not cars.exists(): return "No available cars found matching your criteria."
    result = []
    for car in cars:
        result.append(f"ID: {car.id} | Model: {car.model_name} | Range: {car.range_km}km | Price: ${car.price_per_day}")
    return "\n".join(result)

def create_transaction_draft(user_id: int, car_model_name: str, date_str: str, type: str = 'TEST_DRIVE') -> str:
    """Creates a DRAFT transaction. Returns JSON string with 'meta': 'draft_created'."""
    try:
        user = User.objects.get(id=user_id)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        car = EVCar.objects.filter(model_name__icontains=car_model_name, status='AVAILABLE').first()
        if not car: return f"Error: Could not find an available car matching '{car_model_name}'."
        
        # Use timezone.now() as placeholder for appointment_date since we don't have complex date parsing logic yet
        txn = Transaction.objects.create(
            customer=profile, 
            car=car, 
            type=type, 
            status='DRAFT', 
            appointment_date=timezone.now()
        )
        response_data = {
            "message": f"I have created a draft request for the {car.model_name}.",
            "transaction_id": txn.id,
            "meta": "draft_created"
        }
        return json.dumps(response_data)
    except Exception as e: return f"Error creating draft: {str(e)}"

def cancel_transaction(transaction_id: int) -> str:
    """Cancels a transaction by ID."""
    try:
        txn = Transaction.objects.get(id=transaction_id)
        txn.status = 'CANCELLED'
        txn.save()
        return f"Transaction {transaction_id} has been cancelled."
    except Transaction.DoesNotExist: return "Error: Transaction not found."

class EVSignature(dspy.Signature):
    """
    You are an expert EV consultant.
    1. Answer questions about cars using 'search_cars'.
    2. To onboard a user, you need their Full Name, Nickname, and License ID.
       - IF missing any of these: Ask the user for the missing info.
       - IF all present: Call 'onboard_user'.
    3. Book test drives using 'create_transaction_draft'.
    IMPORTANT: If you create a draft, output the JSON result from the tool directly as your action.
    """
    chat_history = dspy.InputField(desc="Previous conversation turns")
    user_query = dspy.InputField(desc="Latest user message")
    user_id_context = dspy.InputField(desc="The ID of the current user")
    reasoning = dspy.OutputField(desc="Internal thought process")
    action = dspy.OutputField(desc="The result of the tool call or the final answer")

class EVAgent(dspy.Module):
    def __init__(self):
        super().__init__()
        self.prog = dspy.ReAct(EVSignature, tools=[onboard_user, search_cars, create_transaction_draft, cancel_transaction])
    
    def forward(self, history, query, user_id):
        return self.prog(chat_history=history, user_query=query, user_id_context=str(user_id))
EOF

cat > ev_app/views.py <<'EOF'
# ev_app/views.py
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.models import User
from django.contrib.auth import login
from django.utils.crypto import get_random_string
from .models import Transaction
from .dspy_agent import EVAgent
import json
import re

def get_or_create_guest_user(request):
    if not request.user.is_authenticated:
        username = f"guest_{get_random_string(5)}"
        user = User.objects.create_user(username=username)
        login(request, user)
    return request.user

def extract_json_widget(text):
    """Robustly extracts the JSON widget data even if surrounded by text."""
    try:
        match = re.search(r'(\{.*"meta":\s*"draft_created".*\})', text, re.DOTALL | re.IGNORECASE)
        if match:
            json_str = match.group(1)
            return json.loads(json_str)
    except:
        return None
    return None

def chat_view(request):
    user = get_or_create_guest_user(request)
    if 'chat_history' not in request.session: request.session['chat_history'] = []
    context = {}

    if request.method == "POST":
        user_query = request.POST.get('user_query')
        if user_query:
            request.session['chat_history'].append({"role": "user", "text": user_query})
            request.session.modified = True
            
            agent = EVAgent()
            history_str = "\n".join([f"{msg['role'].upper()}: {msg['text']}" for msg in request.session['chat_history']])
            
            try:
                prediction = agent(history=history_str, query=user_query, user_id=user.id)
                agent_response = prediction.action
                
                widget_data = extract_json_widget(agent_response)
                draft_txn = None
                
                if widget_data:
                    agent_response = widget_data.get("message", agent_response)
                    txn_id = widget_data.get("transaction_id")
                    if txn_id:
                        draft_txn = Transaction.objects.filter(id=txn_id).first()

                request.session['chat_history'].append({"role": "ai", "text": agent_response})
                request.session.modified = True
                
                if draft_txn: 
                    context['draft_transaction'] = draft_txn

            except Exception as e:
                request.session['chat_history'].append({"role": "ai", "text": f"Error: {str(e)}"})
                request.session.modified = True

    context['chat_history'] = request.session['chat_history']
    return render(request, 'chat.html', context)

def confirm_transaction(request):
    if request.method == "POST":
        txn = get_object_or_404(Transaction, id=request.POST.get('transaction_id'), customer__user=request.user)
        txn.status = 'CONFIRMED'
        txn.save()
        request.session['chat_history'].append({"role": "ai", "text": f"✅ Great! Transaction #{txn.id} for {txn.car.model_name} is CONFIRMED."})
        request.session.modified = True
    return redirect('chat')
EOF

cat > ev_app/urls.py <<'EOF'
# ev_app/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('', views.chat_view, name='chat'),
    path('chat/', views.chat_view, name='chat_view'),
    path('confirm/', views.confirm_transaction, name='confirm_transaction'),
]
EOF

cat > ev_app/admin.py <<'EOF'
# ev_app/admin.py
from django.contrib import admin
from .models import UserProfile, EVCar, Transaction

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'full_name', 'nickname', 'license_id', 'phone')

@admin.register(EVCar)
class EVCarAdmin(admin.ModelAdmin):
    list_display = ('model_name', 'status', 'price_per_day', 'range_km')
    list_filter = ('status',)

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'car', 'type', 'status', 'appointment_date', 'created_at')
    list_filter = ('status', 'type')
EOF

echo "📝 Populating Data Loader..."
cat > ev_app/management/commands/load_inventory.py <<EOF
import csv
import os
from django.core.management.base import BaseCommand
from ev_app.models import EVCar

class Command(BaseCommand):
    help = 'Load EV inventory from CSV'

    def handle(self, *args, **options):
        file_path = '/app/data/cars.csv'
        if not os.path.exists(file_path):
            self.stdout.write(self.style.WARNING(f'Data file not found at {file_path}'))
            return
        
        with open(file_path, 'r') as f:
            reader = csv.DictReader(f)
            count = 0
            for row in reader:
                obj, created = EVCar.objects.update_or_create(
                    model_name=row['model_name'],
                    defaults={
                        'range_km': int(row['range_km']),
                        'price_per_day': float(row['price_per_day']),
                        'status': row['status']
                    }
                )
                if created:
                    count += 1
            
        self.stdout.write(self.style.SUCCESS(f'Successfully loaded/updated inventory.'))
EOF
touch ev_app/management/__init__.py
touch ev_app/management/commands/__init__.py

echo "📝 Populating Templates..."
cat > templates/base.html <<'EOF'
<!-- templates/base.html -->
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EV Rental Agent</title>
    <script src="{% static 'js/tailwindcss.js' %}"></script>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 text-gray-900 font-sans h-screen flex flex-col">
    <header class="bg-white shadow-sm p-4">
        <div class="max-w-2xl mx-auto flex justify-between items-center">
            <h1 class="text-xl font-bold text-blue-600">⚡ EV Agent</h1>
            {% if user.is_authenticated %}<span class="text-xs text-gray-500">Logged in as: {{ user.username }}</span>{% endif %}
        </div>
    </header>
    <main class="flex-1 flex flex-col overflow-hidden">
        {% block content %}{% endblock %}
    </main>
</body>
</html>
EOF

cat > templates/chat.html <<'EOF'
<!-- templates/chat.html -->
{% extends "base.html" %}
{% block content %}
<div class="max-w-2xl mx-auto w-full p-4 flex flex-col h-full">
    <div class="flex-1 overflow-y-auto space-y-4 mb-4 bg-white p-4 rounded-lg shadow-inner border border-gray-200">
        {% if not chat_history %}
            <div class="text-center text-gray-400 mt-10">
                <p>Hello! I'm your EV Assistant.</p>
                <p class="text-sm">Try: "Book a Tesla" or "Onboard me (Name: John, Nickname: Johnny, License: 12345)"</p>
            </div>
        {% endif %}
        {% for msg in chat_history %}
            <div class="flex flex-col space-y-1 {% if msg.role == 'user' %}items-end{% else %}items-start{% endif %}">
                <div class="px-4 py-2 rounded-2xl max-w-[85%] text-sm shadow-sm
                    {% if msg.role == 'user' %}bg-blue-600 text-white rounded-br-none
                    {% else %}bg-gray-100 text-gray-800 rounded-bl-none border border-gray-200{% endif %}">
                    {{ msg.text }}
                </div>
            </div>
        {% endfor %}
        {% if draft_transaction %}
            <div class="w-full max-w-sm bg-white border border-blue-200 rounded-xl shadow-lg mt-4 mr-auto animate-pulse-once">
                <div class="bg-blue-50 p-3 border-b border-blue-100 flex justify-between items-center">
                    <h3 class="font-bold text-blue-800">📝 Confirm Request</h3>
                    <span class="text-xs bg-blue-200 text-blue-800 px-2 py-0.5 rounded-full">Draft</span>
                </div>
                <div class="p-4 text-sm space-y-2">
                    <p><strong>Car:</strong> {{ draft_transaction.car.model_name }}</p>
                    <p><strong>Price:</strong> ${{ draft_transaction.car.price_per_day }}/day</p>
                    <p><strong>Appointment:</strong> {{ draft_transaction.appointment_date }}</p>
                </div>
                <div class="p-3 bg-gray-50">
                    <form method="POST" action="{% url 'confirm_transaction' %}">
                        {% csrf_token %}
                        <input type="hidden" name="transaction_id" value="{{ draft_transaction.id }}">
                        <button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 rounded-lg">Confirm</button>
                    </form>
                </div>
            </div>
        {% endif %}
        <div id="bottom"></div>
    </div>
    
    <!-- Updated Form with Input Clearing Logic -->
    <form method="POST" class="flex gap-2 bg-white p-2 rounded-xl border shadow-sm"
          onsubmit="setTimeout(() => this.reset(), 10)">
        {% csrf_token %}
        <input type="text" name="user_query" class="flex-1 bg-transparent border-none focus:ring-0 px-3" placeholder="Type your message..." autocomplete="off" autofocus required>
        <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white p-2 rounded-lg">Send</button>
    </form>
    
    <script>window.onload=function(){document.getElementById('bottom').scrollIntoView();}</script>
</div>
{% endblock %}
EOF

echo "📝 Populating Data (cars.csv)..."
cat > data/cars.csv <<EOF
model_name,range_km,price_per_day,status
Tesla Model 3,450,2500,AVAILABLE
BYD Atto 3,420,1800,AVAILABLE
ORA Good Cat,400,1500,AVAILABLE
BMW iX,600,5000,AVAILABLE
EOF

echo "⬇️ Downloading Tailwind CSS..."
if curl -L -o static/js/tailwindcss.js https://cdn.tailwindcss.com; then
    echo "✅ Tailwind CSS downloaded successfully."
else
    echo "⚠️ Download failed. Creating placeholder."
    echo "// Tailwind CSS Placeholder" > static/js/tailwindcss.js
fi

echo "✅ Master Install Complete!"
echo "----------------------------------------------------"
echo "1. Go into the folder: cd $PROJECT_ROOT"
echo "2. Edit .env and add your GEMINI_API_KEY"
echo "3. Run: docker-compose up --build"
echo "----------------------------------------------------"
