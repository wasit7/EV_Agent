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
