# DSPy 101: From Prompting to Programming

**Goal:** Understand the building blocks of DSPy to prepare for advanced AI Engineering Patterns.

## 1\. The Mindset Shift

Traditional AI development is **Prompt Engineering**: strictly manipulating string templates (`f"You are a helpful assistant... User says: {input}"`). This is brittle and hard to optimize.

**DSPy** (Declarative Self-improving Python) treats LLMs as **programmable components**. Instead of writing prompts, you define:

1.  **Signatures:** *What* you want (Inputs/Outputs).
2.  **Modules:** *How* to get it (Strategies like Chain of Thought or ReAct).
3.  **Optimizers:** *How to improve* (Compiling prompts based on data).

## 2\. Core Concepts & Code

### A. Configuration

First, you tell DSPy which "Brain" (LLM) to use.

```python
import dspy

# Configure the Language Model
# You can swap this string for 'openai/gpt-4o', 'anthropic/claude-3', etc.
lm = dspy.LM('gemini/gemini-1.5-flash', api_key="YOUR_API_KEY")
dspy.configure(lm=lm)
```

### B. Signatures (The Interface)

A **Signature** is a declarative specification of input and output fields. It describes the *task* without writing the prompt instructions manually.

```python
class SentimentSignature(dspy.Signature):
    """Classify the sentiment of the text and extract the main subject."""
    
    text_content = dspy.InputField(desc="The sentence to analyze")
    sentiment = dspy.OutputField(desc="Positive, Negative, or Neutral")
    subject = dspy.OutputField(desc="The main object or person being discussed")
```

### C. Modules (The Logic)

Modules wrap Signatures to define the "thinking process." They work like layers in a neural network (PyTorch).

  * **`dspy.Predict`**: The simplest module. Input $\rightarrow$ Output.
  * **`dspy.ChainOfThought`**: Forces the model to generate a "Reasoning" field before the answer. Increases accuracy significantly.
  * **`dspy.ReAct`**: The agentic loop. Input $\rightarrow$ Thought $\rightarrow$ Action (Tool) $\rightarrow$ Output.

#### Runnable Example: Chain of Thought

```python
# 1. Instantiate the Module with our Signature
predictor = dspy.ChainOfThought(SentimentSignature)

# 2. Run it (Forward pass)
response = predictor(text_content="The battery life on this EV is amazing, but charging is slow.")

# 3. Inspect Results
print(f"Reasoning: {response.reasoning}")
print(f"Sentiment: {response.sentiment}")
print(f"Subject:   {response.subject}")
```

## 3\. Connecting to Design Patterns

Now that you understand the syntax, here is how it maps to the **AI Engineering Patterns** document:

| DSPy Concept | Corresponding Design Pattern |
| :--- | :--- |
| **`dspy.ReAct`** | **Pattern 1 (The ReAct Loop):** This module automates the complex "Thought-Action-Observation" loop so you don't have to parse strings manually. |
| **`tools=[...]`** | **Pattern 2 (Tool Use):** You pass Python functions into the ReAct module. DSPy handles the function calling protocol for you. |
| **`dspy.OutputField`** | **Pattern 4 (Structured Extraction):** By defining fields like `license_id` or `booking_date` in a Signature, DSPy guarantees structured extraction from the LLM. |
| **Optimizer** | **Pattern 13 (Few-Shot Learning):** Instead of writing examples in your prompt, you feed a dataset to a DSPy Optimizer (e.g., `BootstrapFewShot`). It *compiles* your code, finding the best examples to inject automatically. |

## 4\. Summary for Developers

1.  **Stop writing string prompts.** Define **Signatures** instead.
2.  **Stop managing context manually.** Use **Modules** to handle history and reasoning.
3.  **Start compiling.** Use **Optimizers** to treat your prompt like a hyperparameter that improves over time.

## 5\. Advance Patterns