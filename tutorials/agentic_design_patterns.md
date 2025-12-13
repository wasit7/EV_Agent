# Agentic Design Patterns

**Domain:** Large Language Model (LLM) Application Architecture
**Target Frameworks:** DSPy, Django, Python

This document formalizes architectural and agentic design patterns for building robust, production-grade AI applications.

## 🛠️ Prerequisite: Shared Initialization Code

To ensure the examples below are concise and runnable, assume the following setup code has already been executed. This mocks the Django environment and configures DSPy.

```python
import dspy
import json
import re
from typing import List, Optional

# 1. Configure DSPy (Using a Dummy LM for demonstration, replace with real LM in prod)
lm = dspy.DummyLM([
    "Reasoning: I need to search for a car first.",
    "Action: search_cars(query='Tesla')",
    "Answer: We have a Tesla Model 3 available."
])
dspy.configure(lm=lm)

# 2. Mocking Django Models (to make examples standalone)
class MockManager:
    def __init__(self, data=None): self.data = data or []
    def filter(self, **kwargs): return [d for d in self.data if all(getattr(d, k) == v for k, v in kwargs.items())]
    def create(self, **kwargs):
        obj = MockModel(**kwargs)
        obj.id = 123
        return obj
    def get(self, id): return MockModel(id=id, status='DRAFT')

class MockModel:
    objects = MockManager()
    def __init__(self, **kwargs):
        for k, v in kwargs.items(): setattr(self, k, v)
    def save(self): pass

# 3. Mock Database State
EVCar_objects = MockManager([
    MockModel(id=1, model_name="Tesla Model 3", status="AVAILABLE", price=100),
    MockModel(id=2, model_name="BYD Atto 3", status="AVAILABLE", price=80)
])
```

## 🧠 Part 1: Agentic Patterns (Cognitive Architectures)

### 1\. The ReAct Loop (Reason + Act)

**Definition:** An execution model where the agent iteratively generates a "Thought" (Reasoning), performs an "Action" (Tool Call), and observes the "Result" before producing a final answer.

**Problem:** LLMs cannot natively interact with external systems (Databases, APIs) and often hallucinate when asked to perform multi-step tasks requiring data they don't possess.

**Solution:** Decompose the task into a loop of reasoning and acting steps using a predefined signature.

**Implementation:**

```python
# Define a simple tool
def search_cars(query: str) -> str:
    """Searches the database for cars."""
    return "Found: Tesla Model 3 (ID: 1), BYD Atto 3 (ID: 2)"

# Define the ReAct Agent
class CarRentalAgent(dspy.Module):
    def __init__(self):
        # DSPy automatically handles the Thought -> Action -> Observation loop
        self.prog = dspy.ReAct("question -> answer", tools=[search_cars])

    def forward(self, question):
        return self.prog(question=question)

# Usage
agent = CarRentalAgent()
response = agent(question="Find me a Tesla")
print(f"Agent Action: {lm.history[-1]}") # Inspects the last internal call
```

### 2\. Tool Use (Function Calling)

**Definition:** Exposing deterministic functions to a probabilistic model. The model outputs a structured string (Action) which the host system parses and executes.

**Problem:** LLMs have a knowledge cutoff and are isolated from real-time application state.

**Solution:** Provide the LLM with a list of function signatures it can "call" to retrieve information or modify state.

**Implementation:**

```python
# The Tool Logic (Deterministic)
def check_availability(car_id: int) -> str:
    """Checks if a specific car ID is available."""
    # In real app: return EVCar.objects.get(id=car_id).status
    return "AVAILABLE"

# The Binding (Agentic)
# The agent is initialized with the tool list
agent = dspy.ReAct("request -> response", tools=[check_availability])

# Prompt Context (Conceptual):
# "You have access to tools: check_availability(car_id).
#  To check car 1, output: check_availability(car_id=1)"
```

### 3\. Chain of Thought (CoT)

**Definition:** Instructing the model to generate intermediate reasoning steps before the final answer to improve logical accuracy.

**Problem:** Zero-shot inference often fails on complex logic or arithmetic because the model attempts to predict the final token immediately without "scratchpad" space.

**Solution:** Allocate generation tokens to reasoning.

**Implementation:**

```python
class CoTSignature(dspy.Signature):
    """Solve the problem by thinking step-by-step."""
    question = dspy.InputField()
    # This output field forces the model to generate reasoning tokens first
    reasoning = dspy.OutputField(desc="Step-by-step logic")
    answer = dspy.OutputField(desc="Final result")

# Usage
program = dspy.ChainOfThought(CoTSignature)
pred = program(question="If I book a car for 3 days at $100/day with 10% tax, total?")
# Expected Reasoning: 3 * 100 = 300. 10% of 300 is 30. 300 + 30 = 330.
# Expected Answer: 330
```

### 4\. Structured Extraction

**Definition:** Using an LLM to parse unstructured natural language into a strictly defined schema (JSON/Objects).

**Problem:** User input is messy ("I'm John, license is 555"), but databases require structured columns.

**Solution:** Use a Signature to map entropy (text) to structure (fields).

**Implementation:**

```python
class OnboardingExtractor(dspy.Signature):
    """Extract user details from the conversation."""
    chat_log = dspy.InputField()
    full_name = dspy.OutputField()
    license_id = dspy.OutputField()
    nickname = dspy.OutputField(desc="Short name if provided, else empty")

extractor = dspy.Predict(OnboardingExtractor)
result = extractor(chat_log="Hi, call me Mike. My real name is Michael Scott, license A-99.")

# Result acts like a Pydantic object
# result.full_name -> "Michael Scott"
# result.nickname -> "Mike"
# result.license_id -> "A-99"
```

### 5\. Retrieval-Augmented Generation (Simple RAG)

**Definition:** Injecting relevant data retrieved from a reliable source (Database) into the prompt context *before* generation.

**Problem:** LLMs hallucinate inventory or lack access to private database records.

**Solution:** Fetch data first, then ask the LLM to synthesize the answer based *only* on that data.

**Implementation:**

```python
def rag_search_tool(query):
    # 1. Retrieval: Query the "Database"
    cars = EVCar_objects.filter(status="AVAILABLE")
    
    # 2. Augmentation: Format as context string
    context_str = "\n".join([f"- {c.model_name} (${c.price})" for c in cars])
    
    # 3. Generation: DSPy Agent uses this context
    return context_str

# The agent receives the output of this tool as 'observation' 
# and uses it to generate the final answer.
```

### 6\. System Persona Implementation

**Definition:** Encoding behavioral constraints, tone, and rules into the static system prompt.

**Problem:** Agents without defined boundaries can be manipulated or drift off-topic.

**Solution:** Define a "Constitution" in the docstring.

**Implementation:**

```python
class SecureEVSignature(dspy.Signature):
    """
    You are an EV Rental Consultant.
    
    CONSTRAINTS:
    1. NEVER confirm a booking without checking availability.
    2. NEVER ask for credit card numbers in chat.
    3. Always be polite but concise.
    """
    history = dspy.InputField()
    response = dspy.OutputField()

# The docstring is compiled into the system prompt sent to the LLM.
agent = dspy.Predict(SecureEVSignature)
```

## 🏗️ Part 2: Architectural Patterns (System Design)

### 7\. The Draft-Confirm Pattern

**Definition:** A safety pattern where the AI can only create "Draft" records. A human must perform a deterministic action (click) to transition the state to "Confirmed".

**Problem:** AI is probabilistic and may book the wrong date or car.

**Solution:** Decouple Proposal (AI) from Execution (User).

**Implementation:**

```python
# 1. AI Tool: Creates Draft ONLY
def create_draft(car_name: str):
    # Creates record with status='DRAFT'
    txn = MockModel.objects.create(car_name=car_name, status='DRAFT')
    return json.dumps({"msg": "Draft created", "id": txn.id, "meta": "draft_created"})

# 2. Django View (User Action): Confirms
def confirm_booking_view(request, txn_id):
    # Deterministic State Transition
    txn = MockModel.objects.get(id=txn_id)
    txn.status = 'CONFIRMED'
    txn.save()
    return "Booking Confirmed!"
```

### 8\. Hybrid / Generative UI

**Definition:** Dynamically rendering UI widgets on the client based on AI intent, rather than just text.

**Problem:** Text chat is inefficient for reviewing complex details (dates, prices, car specs).

**Solution:** Embed structured widgets in the chat stream.

**Implementation:**

```python
def chat_view_logic(ai_response_text):
    # 1. Regex to find hidden JSON signature from Agent
    match = re.search(r'(\{.*"meta":\s*"draft_created".*\})', ai_response_text)
    
    widget_context = None
    if match:
        # 2. Extract Data
        data = json.loads(match.group(1))
        
        # 3. Prepare Widget Context for Template
        widget_context = {
            "type": "booking_card",
            "transaction_id": data['id']
        }
    
    return widget_context
    # Template renders: {% if widget.type == 'booking_card' %} <div class="card">... {% endif %}
```

### 9\. State Injection

**Definition:** Manually retrieving conversation history and user context from persistence and injecting it into the prompt for every request.

**Problem:** LLMs (via API) are stateless. They don't remember the previous request.

**Solution:** The Application Layer acts as the memory.

**Implementation:**

```python
def handle_request(request):
    # 1. Fetch History from Session (The "Memory")
    chat_history = request.session.get('history', [])
    
    # 2. Fetch User Context
    user_context = f"User License: {request.user.license_id}"
    
    # 3. Inject into Agent
    agent = dspy.ReAct("history, user_context, query -> answer")
    response = agent(history=chat_history, user_context=user_context, query=request.POST['msg'])
    
    return response
```

### 10\. Robust Output Parsing

**Definition:** Using resilient parsing (Regex) to extract data, anticipating that LLMs may wrap JSON in conversational text.

**Problem:** An agent might output *"Here is the JSON: `{"id": 1}`"* instead of just `{"id": 1}`, breaking `json.loads()`.

**Solution:** Hunt for the structure.

**Implementation:**

```python
def safe_parse(llm_output):
    # Don't trust the LLM to output pure JSON.
    # Look for the curly braces explicitly.
    json_match = re.search(r'(\{.*\})', llm_output, re.DOTALL)
    
    if json_match:
        try:
            return json.loads(json_match.group(1))
        except json.JSONDecodeError:
            pass
    return None
```

### 11\. Tool-Level Validation

**Definition:** Implementing strict validation logic inside the tools, serving as a "defense in depth" against malformed AI inputs.

**Problem:** The ReAct agent might hallucinate arguments (e.g., passing a string "five" instead of integer `5`).

**Solution:** Tools should validate inputs and return descriptive errors to the agent so it can self-correct.

**Implementation:**

```python
def onboard_tool(age: str):
    # 1. Validation Logic
    if not age.isdigit():
        # Return error to Agent (not user) so Agent can try again
        return "Error: Age must be a number."
    
    age_int = int(age)
    if age_int < 18:
        return "Error: User must be 18+ to rent."
        
    # 2. Execution
    return "Success"
```

### 12\. Prompt Optimization (The DSPy Compiler)

**Definition:** Replacing manual prompt engineering with a programmatic optimization process. A dataset of input-output pairs is used to "compile" the agent, automatically selecting the best few-shot examples or instructions.

**Problem:** Hand-writing prompts is tedious and often regresses when models change.

**Solution:** Treat the prompt as a set of weights that can be learned from data.

**Implementation:**

```python
# 1. Define the Metric (What defines success?)
def validate_car_search(example, pred, trace=None):
    # Check if the predicted car ID matches the gold label
    return example.expected_car_id in pred.answer

# 2. Define the Optimizer
from dspy.teleprompt import BootstrapFewShot

# 3. Compile
# 'trainset' would contain Examples like: dspy.Example(question="Need a Tesla", expected_car_id="1")
teleprompter = BootstrapFewShot(metric=validate_car_search)
compiled_agent = teleprompter.compile(CarRentalAgent(), trainset=[]) # Pass real trainset here

# Now 'compiled_agent' has optimized prompts/demos embedded
```

### 13\. The Supervisor (Routing)

**Definition:** A hierarchical pattern where a top-level "Supervisor" agent classifies user intent and routes the request to a specialized sub-agent (Worker) rather than one agent handling everything.

**Problem:** Single agents with too many tools (Sales, Support, Booking, Technical) become confused and less accurate.

**Solution:** Divide and conquer.

**Implementation:**

```python
class Router(dspy.Signature):
    """Classify the user intent into one of: ['Sales', 'Support']."""
    query = dspy.InputField()
    intent = dspy.OutputField()

class SupervisorModule(dspy.Module):
    def __init__(self):
        self.classify = dspy.Predict(Router)
        self.sales_bot = CarRentalAgent() # From Pattern 1
        self.support_bot = dspy.Predict("q -> answer") 

    def forward(self, query):
        intent = self.classify(query=query).intent
        if intent == 'Sales':
            return self.sales_bot(question=query)
        else:
            return self.support_bot(q=query)
```

### 14\. Self-Correction (Reflexion)

**Definition:** Adding a review step where the agent critiques its own output against a set of rules or logical checks before returning the final response.

**Problem:** LLMs often make confident errors that they can catch if asked to "double check".

**Solution:** Generate, Critique, Refine.

**Implementation:**

```python
class Checker(dspy.Signature):
    """Check if the answer contains a valid car ID."""
    proposal = dspy.InputField()
    is_valid = dspy.OutputField(desc="True/False")
    feedback = dspy.OutputField()

class SelfCorrectingAgent(dspy.Module):
    def __init__(self):
        self.generate = CarRentalAgent()
        self.check = dspy.Predict(Checker)

    def forward(self, query):
        # 1. Generate
        pred = self.generate(question=query)
        
        # 2. Critique
        critique = self.check(proposal=pred.answer)
        
        # 3. Refine (if needed)
        if critique.is_valid == "False":
            # Re-run with feedback injected
            return self.generate(question=f"{query} (Note: {critique.feedback})")
        
        return pred
```

## 🛡️ Part 3: Reliability & Scaling Patterns

### 15\. Long-Term Memory (Episodic Retrieval)

**Definition:** Extending the agent's context window by storing past interactions in a Vector Database and retrieving relevant "memories" based on semantic similarity.

**Problem:** Agents forget details from conversations that happened days or weeks ago (Context Window limits).

**Solution:** Store conversations as embeddings; Retrieve relevant chunks before generation.

**Implementation:**

```python
# Mocking a Vector DB client
def query_vector_db(user_id, query_text):
    # In reality: client.query(collection=user_id, vector=embed(query_text))
    return "User previously liked Red Cars and mentioned a budget of $50/day."

class MemoryAgent(dspy.Module):
    def __init__(self):
        self.prog = dspy.ChainOfThought("context, question -> answer")
    
    def forward(self, user_id, question):
        # 1. Retrieve "Memories"
        long_term_context = query_vector_db(user_id, question)
        
        # 2. Inject into Context
        return self.prog(context=long_term_context, question=question)
```

### 16\. The Human Escalation Pattern (Circuit Breaker)

**Definition:** A mechanism to detect agent failure, low confidence, or user frustration, and gracefully hand off the session to a human operator.

**Problem:** AI is not 100% reliable. Trapping a user in a loop of "I didn't understand that" destroys trust.

**Solution:** Monitoring metrics or explicit intent to trigger an "Escalation".

**Implementation:**

```python
def escalation_tool(reason: str):
    """Triggers a human alert system."""
    # Django Logic: Ticket.objects.create(status='OPEN', priority='HIGH')
    return "ESCALATED: A human agent has been notified and will join shortly."

class SupportSignature(dspy.Signature):
    """Answer support queries. If unsure or user is angry, call 'escalate_to_human'."""
    query = dspy.InputField()
    answer = dspy.OutputField()

# If the agent calls 'escalate_to_human', the UI can switch modes
# from "AI Chat" to "Live Support Waiting Queue".
```

### 17\. Semantic Caching (Cost Optimization)

**Definition:** Storing LLM responses indexed by the *meaning* (embedding) of the input prompt, rather than an exact text match.

**Problem:** LLM calls are expensive and slow. Users often ask the same questions slightly differently ("What is the price?" vs "How much does it cost?").

**Solution:** Check the semantic cache before calling the LLM.

**Implementation:**

```python
# Pseudo-code for Semantic Cache
cache = {
    "embedding_vector_for_price": "The Tesla is $100/day."
}

def get_response(user_query):
    # 1. Calculate Embedding
    query_vec = [0.1, 0.5, ...] # embed(user_query)
    
    # 2. Check Cache (Cosine Similarity > 0.95)
    # if similarity(query_vec, stored_vec) > threshold:
    #    return cached_response
    
    # 3. Call LLM (Miss)
    return dspy_agent(user_query)
```

## 🔄 Part 4: Feedback & Improvement Patterns

### 18\. The "Data Flywheel" (Implicit Feedback)

**Definition:** Automatically capturing user interactions (such as corrections to a draft or edits to a form) to create a dataset for future fine-tuning or few-shot compilation.

**Problem:** Manually creating training datasets is expensive. Users are constantly "correcting" the AI, but that data is usually lost.

**Solution:** Diff the "AI Proposal" vs. "User Final Action" and save it.

**Implementation:**

```python
def capture_feedback(user_query: str, ai_draft_car_id: int, user_final_car_id: int):
    """
    Called when a user confirms a booking.
    If they changed the car, it implies the AI's initial draft was wrong.
    """
    if ai_draft_car_id != user_final_car_id:
        # Save as a negative example or a correction pair
        # Dataset.objects.create(input=user_query, bad_output=ai_draft, good_output=user_final)
        print(f"Captured correction: User wanted {user_final_car_id}, not {ai_draft_car_id}")
        return "Feedback Saved"
    return "No Correction"
```

### 19\. Automated Evaluation (The Metric)

**Definition:** Codifying "quality" into a deterministic function that can score an AI's response (True/False or 0-100), enabling the use of DSPy Optimizers.

**Problem:** You cannot optimize what you cannot measure. "It feels better" is not a scalable engineering metric.

**Solution:** Write code that checks the answer against a Gold Standard or logical constraints.

**Implementation:**

```python
def car_search_metric(example, pred, trace=None):
    """
    A metric function for DSPy optimization.
    Returns True if the predicted answer mentions the expected car model.
    """
    # 'example' comes from your training set (Ground Truth)
    # 'pred' is what the AI just output
    
    expected_model = example.gold_car_model.lower()
    predicted_text = pred.answer.lower()
    
    # Metric: Exact string match of the car model
    return expected_model in predicted_text
```

### 20\. PII Scrubbing (Privacy Guardrails)

**Definition:** A middleware layer that detects and redacts Personally Identifiable Information (PII) *before* it is sent to the LLM provider, and optionally re-hydrates it on return.

**Problem:** Sending user emails, phone numbers, or credit cards to a 3rd party LLM API violates privacy compliance (GDPR/HIPAA).

**Solution:** Regex-based substitution or specialized NER (Named Entity Recognition) models.

**Implementation:**

```python
def pii_scrubber(text: str) -> str:
    """Redacts emails and phone numbers before they hit the LLM."""
    # Simple Regex for emails
    text = re.sub(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b', '<EMAIL_REDACTED>', text)
    # Simple Regex for phone numbers
    text = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '<PHONE_REDACTED>', text)
    return text

class PrivateAgent(dspy.Module):
    def __init__(self):
        self.prog = dspy.Predict("question -> answer")
        
    def forward(self, question):
        # 1. Scrub Input
        clean_q = pii_scrubber(question)
        
        # 2. Call LLM with safe data
        return self.prog(question=clean_q)
```

### 21\. Sequential Chaining (The Pipeline)

**Definition:** Decomposing a complex task into a deterministic sequence of simpler DSPy modules, where the output of one becomes the input of the next.

**Problem:** Trying to do too much in a single prompt (e.g., "Translate, Summary, and Format") often degrades quality across all tasks.

**Solution:** Pipelining small, specialized modules.

**Implementation:**

```python
class Translate(dspy.Signature):
    """Translate text to English."""
    text = dspy.InputField()
    english_text = dspy.OutputField()

class Summarize(dspy.Signature):
    """Summarize the text."""
    text = dspy.InputField()
    summary = dspy.OutputField()

class PipelineAgent(dspy.Module):
    def __init__(self):
        self.step1 = dspy.Predict(Translate)
        self.step2 = dspy.Predict(Summarize)

    def forward(self, raw_text):
        # Step 1: Translate
        translation = self.step1(text=raw_text).english_text
        
        # Step 2: Summarize (Input is output of Step 1)
        final = self.step2(text=translation)
        
        return final
```

### 22\. The Simulator (Synthetic User)

**Definition:** Creating a second "User Agent" to interact with your "System Agent" automatically, generating synthetic conversation logs for testing and optimization.

**Problem:** Gathering real user data for optimization is slow and raises privacy concerns.

**Solution:** Use an LLM to simulate the user.

**Implementation:**

```python
class UserSimulator(dspy.Module):
    def __init__(self):
        self.prog = dspy.Predict("system_reply -> user_followup")
    
    def forward(self, system_reply):
        # Simulates a user who wants to book a Tesla
        return self.prog(
            system_reply=system_reply, 
            goal="I want to rent a Tesla Model 3. Reject any other car."
        )

# Loop them together
def run_simulation():
    agent = CarRentalAgent()
    user = UserSimulator()
    
    history = []
    user_input = "Hi"
    
    for _ in range(3):
        # Agent Turn
        agent_response = agent(question=user_input).answer
        print(f"Agent: {agent_response}")
        
        # User Turn
        user_input = user(system_reply=agent_response).user_followup
        print(f"User:  {user_input}")
```

### 23\. Shadow Mode (Safe Deployment)

**Definition:** Running a new version of an agent in production alongside the current version. The user sees the old version's output, but the new version's output is logged for offline comparison.

**Problem:** You cannot know if a prompt update is "better" without production data, but deploying it directly is risky.

**Solution:** Parallel execution without serving.

**Implementation:**

```python
def handle_request(user_query):
    # 1. Run Production Agent (Trusted)
    prod_agent = CarRentalAgent()
    prod_response = prod_agent(question=user_query)
    
    # 2. Run Candidate Agent (Experimental) - Asynchronously if possible
    candidate_agent = NewExperimentalAgent()
    candidate_response = candidate_agent(question=user_query)
    
    # 3. Log diff
    log_comparison(prod_response, candidate_response)
    
    # 4. Return ONLY Production response to user
    return prod_response
```