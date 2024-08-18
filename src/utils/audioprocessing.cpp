#include "audioprocessing.h"
#include <cmath>
#include <algorithm>
#include <numeric>

AGC::AGC(float targetLevelDb, float attackTimeMs, float releaseTimeMs, float lookAheadTimeMs, float sr)
    : sample_rate(sr) {
    target_level = std::pow(10.0f, targetLevelDb / 20.0f);
    attack_time = attackTimeMs / 1000.0f;
    release_time = releaseTimeMs / 1000.0f;
    look_ahead_samples = static_cast<size_t>(lookAheadTimeMs * sr / 1000.0f);
    
    gain = 1.0f;
    max_gain = 100000.0f; // Increased for better amplification of quiet signals
    min_gain = 0.01f;     // Decreased for better attenuation of loud signals
    average_level = target_level;
    
    lookahead_buffer.resize(look_ahead_samples);
    level_history.resize(static_cast<size_t>(sr * 0.1f), target_level); // Reduced to 100ms for faster response
}

float AGC::computeGain(float input_level) {
    // More aggressive gain computation
    return std::pow(target_level / (input_level + 1e-6f), 0.75f);
}

float AGC::smoothGain(float new_gain) {
    // Faster attack and release times
    float time_constant = (new_gain > gain) ? attack_time * 0.5f : release_time * 0.5f;
    float alpha = 1.0f - std::exp(-1.0f / (time_constant * sample_rate));
    return gain + alpha * (new_gain - gain);
}

void AGC::process(float *arr, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        lookahead_buffer.push_back(std::abs(arr[i]));
        float current_peak = *std::max_element(lookahead_buffer.begin(), lookahead_buffer.end());
        
        level_history.push_back(current_peak);
        level_history.erase(level_history.begin());
        
        float long_term_level = *std::max_element(level_history.begin(), level_history.end());
        
        // Faster adaptation of average level
        average_level = 0.95f * average_level + 0.05f * long_term_level;
        
        float target_gain = computeGain(average_level);
        target_gain = std::clamp(target_gain, min_gain, max_gain);
        
        gain = smoothGain(target_gain);
        
        float processed_sample = arr[i] * gain;
        
        // Soft knee limiter with lower threshold
        const float threshold = 0.8f;
        if (std::abs(processed_sample) > threshold) {
            float excess = std::abs(processed_sample) - threshold;
            processed_sample = (processed_sample > 0 ? 1 : -1) * (threshold + std::tanh(excess));
        }
        
        arr[i] = processed_sample;
        
        lookahead_buffer.pop_front();
    }
}

void AGC::reset() {
    gain = 1.0f;
    average_level = target_level;
    std::fill(lookahead_buffer.begin(), lookahead_buffer.end(), 0.0f);
    std::fill(level_history.begin(), level_history.end(), target_level);
}