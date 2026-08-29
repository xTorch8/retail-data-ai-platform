import logging
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(parents = True, exist_ok = True)

logging.basicConfig(
    filename = LOG_DIR / "app.log",
    filemode = "a",
    format = "%(asctime)s - %(levelname)s - %(message)s",
    level = logging.INFO,
    force = True
)

import gradio as gr
from .services.auth_service import AuthService
from .services.chat_service import ChatService

auth_service = AuthService()
chat_service = ChatService()

def login_handler(username, password):
    logging.info("[INFO][main.py][login_handler] Handling login submission")
    if not username or not password:
        return (
            gr.update(visible = True), 
            gr.update(visible = False), 
            "", 
            "Username and password are required."
        )
    try:
        response = auth_service.login(username, password)
        access_token = response.get("access_token")
        if access_token:
            logging.info("[INFO][main.py][login_handler] Login successful, redirecting to chat page")
            return (
                gr.update(visible = False), 
                gr.update(visible = True), 
                access_token, 
                ""
            )
        else:
            return (
                gr.update(visible = True), 
                gr.update(visible = False), 
                "", 
                "Login failed. No token received."
            )
    except Exception as e:
        logging.warning(f"[WARNING][main.py][login_handler] Login failed: {e}")
        return (
            gr.update(visible = True), 
            gr.update(visible = False), 
            "", 
            f"Error: {str(e)}"
        )

def chat_handler(message, history, token):
    logging.info("[INFO][main.py][chat_handler] Handling chat message")
    if not token:
        logging.warning("[WARNING][main.py][chat_handler] User not authenticated")
        return history, "Please login first."
        
    try:
        response = chat_service.chat(token, message, history)
        payload = response.get("payload", {})
        bot_message = payload.get("message", "No response from assistant.")
        
        history.append({"role": "user", "content": message})
        history.append({"role": "assistant", "content": bot_message})
        
        return history, ""
    except Exception as e:
        logging.error(f"[ERROR][main.py][chat_handler] Chat error: {e}")
        history.append({"role": "user", "content": message})
        history.append({"role": "assistant", "content": f"Error: {str(e)}"})
        return history, f"Error: {str(e)}"

def logout_handler():
    logging.info("[INFO][main.py][logout_handler] Logging out user")
    return (
        gr.update(visible = True), 
        gr.update(visible = False), 
        "", 
        [], 
        ""  
    )

with gr.Blocks(title = "Retail AI Platform", fill_height = True) as demo:
    token_state = gr.State(value = "")

    with gr.Row(visible = True) as login_container:
        gr.Column(scale = 1)
        with gr.Column(scale = 2):
            gr.Markdown("# Retail AI Platform Login")
            with gr.Group():
                username_input = gr.Textbox(label = "Username", placeholder = "Enter your username")
                password_input = gr.Textbox(label = "Password", type = "password", placeholder = "Enter your password")
                login_btn = gr.Button("Login", variant = "primary")
                error_output = gr.Markdown("", label = "Error Details")
        gr.Column(scale = 1)

    with gr.Column(visible = False) as chat_container:
        with gr.Row():
            gr.Markdown("# Retail Data & AI Platform Chat")
            logout_btn = gr.Button("Logout", size = "sm")
            
        chatbot = gr.Chatbot(height = 700)
        
        with gr.Row():
            msg_input = gr.Textbox(
                placeholder = "Ask a question about sales, inventory, stores, or products...",
                show_label = False,
                scale = 8
            )
            submit_btn = gr.Button("Send", variant = "primary", scale = 1)
            
        chat_error_output = gr.Markdown("")

    login_btn.click(
        fn = login_handler,
        inputs = [username_input, password_input],
        outputs = [login_container, chat_container, token_state, error_output]
    )
    
    password_input.submit(
        fn = login_handler,
        inputs = [username_input, password_input],
        outputs = [login_container, chat_container, token_state, error_output]
    )

    def submit_chat_flow(message, history, token):
        if not message or not message.strip():
            return history, "", ""
        new_history, err = chat_handler(message, history, token)
        return new_history, "", err

    submit_btn.click(
        fn = submit_chat_flow,
        inputs = [msg_input, chatbot, token_state],
        outputs = [chatbot, msg_input, chat_error_output]
    )
    
    msg_input.submit(
        fn = submit_chat_flow,
        inputs = [msg_input, chatbot, token_state],
        outputs = [chatbot, msg_input, chat_error_output]
    )

    logout_btn.click(
        fn = logout_handler,
        inputs = None,
        outputs = [login_container, chat_container, token_state, chatbot, msg_input]
    )

if __name__ == "__main__":
    demo.launch(server_name = "0.0.0.0", server_port = 7860)

