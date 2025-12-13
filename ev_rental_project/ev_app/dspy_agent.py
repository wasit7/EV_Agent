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
