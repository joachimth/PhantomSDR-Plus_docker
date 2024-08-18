#include "spectrumserver.h"
#include "chat.h"


std::set<websocketpp::connection_hdl, std::owner_less<websocketpp::connection_hdl>> ChatClient::chat_connections;



ChatClient::ChatClient(connection_hdl hdl, PacketSender &sender)
    : Client(hdl, sender, CHAT){

    on_open_chat(hdl);
}


std::deque<std::string> chat_messages_history; // Store the last 100 messages
std::unordered_map<std::string, std::string> user_id_to_name;

/* clang-format on */


std::string ChatClient::get_or_generate_username(const std::string& user_id) {
    auto it = user_id_to_name.find(user_id);
    if (it != user_id_to_name.end()) {
        // Username already generated
        return it->second;
    } else {
        // Hash the user_id to generate a unique number
        std::hash<std::string> hasher;
        auto hashed = hasher(user_id);

        // Convert part of the hash to a string. Note: This is just an example and might need adjustments
        // to ensure uniqueness or handle potential collisions appropriately.
        std::string numeric_part = std::to_string(hashed).substr(0, 6); // Take first 6 digits

        // Construct the username with "user" prefix
        std::string username = "user" + numeric_part;

        // Save the generated username
        user_id_to_name[user_id] = username;

        return username;
    }
}




void ChatClient::store_chat_message(const std::string& message) {
    // Get current timestamp
    auto now = std::chrono::system_clock::now();
    auto now_c = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    std::string timestamp = ss.str();

    // Store a new message with timestamp, ensuring we don't exceed 100 messages
    if(chat_messages_history.size() >= 100) {
        chat_messages_history.pop_front(); // Remove the oldest message
    }
    chat_messages_history.push_back(timestamp + " " + message); // Add the new message with timestamp
}


std::string ChatClient::get_chat_history_as_string() {
        std::string history;
        for (const auto& msg : chat_messages_history) {
            history += msg + "\n"; // Concatenate messages with a newline
        }
        return history;
    }

    
void ChatClient::on_chat_message(connection_hdl sender_hdl, std::string& user_id, std::string& message) {
    std::string username = get_or_generate_username(user_id);
    
    // Get current timestamp
    auto now = std::chrono::system_clock::now();
    auto now_c = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    std::string timestamp = ss.str();

    std::string formatted_message = timestamp + " " + username + ": " + message;

    store_chat_message(formatted_message);

    // Broadcast the message to all users except the sender
    for (const auto& conn : chat_connections) {
        sender.send_text_packet(conn, formatted_message);
    }
}


void ChatClient::on_open_chat(connection_hdl hdl) {
    chat_connections.insert(hdl);

    // Send chat history to the newly connected client
    if (!chat_messages_history.empty()) {
        std::string history = "Chat history:\n" + get_chat_history_as_string();
        sender.send_text_packet(hdl, history);
    }


}
void ChatClient::on_close_chat(connection_hdl hdl) {
    chat_connections.erase(hdl);
}
