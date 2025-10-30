defmodule Mix.Tasks.Session.Learn do
  @moduledoc """
  Interactive learning extraction at end of session.
  
  Agent proposes key learnings, user corrects/refines, agent documents.
  
  ## Usage
  
      mix session.learn
  """
  
  use Mix.Task
  
  @shortdoc "Interactive learning extraction"
  
  def run([]) do
    Mix.shell().info("""
    
    ╔════════════════════════════════════════════════╗
    ║        Session Learning - Interactive          ║
    ╚════════════════════════════════════════════════╝
    
    This is a conversation between you and the user to extract
    what you learned this session.
    
    YOUR JOB:
    1. Reflect on what you did this session
    2. Propose 1-3 key learnings (be specific!)
    3. User will correct/refine your understanding
    4. You document in the right place in agents/
    
    ═══════════════════════════════════════════════
    
    What did you learn this session?
    
    Format each learning as:
    - **Pattern**: What's the specific pattern/rule?
    - **Context**: When does this apply?
    - **Example**: Code or concrete example
    - **Why**: Why does this matter?
    
    Be succinct. Focus on what future agents need to know.
    
    """)
    
    Mix.shell().info("Start the conversation with your proposed learnings.")
    Mix.shell().info("User will guide you to refine and document correctly.")
  end
  
  def run(_) do
    Mix.shell().error("Usage: mix session.learn")
    Mix.shell().info("This starts an interactive learning conversation.")
  end
end
