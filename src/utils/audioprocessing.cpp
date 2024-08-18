#include "audioprocessing.h"
#include <algorithm>
#include <numeric>

AGC::AGC(float targetLevelDb, float attackTimeMs, float releaseTimeMs, float lookAheadTimeMs, float sr)
    : sample_rate(sr) {
    setTargetLevel(targetLevelDb);
    setAttackTime(attackTimeMs);
    setReleaseTime(releaseTimeMs);
    look_ahead_samples = static_cast<size_t>(lookAheadTimeMs * sr / 1000.0f);
    
    gain = 1.0f;
    max_gain = 100.0f;  // Increased for better amplification of very quiet signals
    min_gain = 0.001f;  // Decreased for better attenuation of very loud signals
    average_level = target_level;
    
    lookahead_buffer.resize(look_ahead_samples);
    level_history.resize(static_cast<size_t>(sr * 0.05f), target_level);  // Reduced to 50ms for faster response
}

float AGC::computeGain(float input_level) {
    float ratio = target_level / (input_level + 1e-6f);
    return std::pow(ratio, 0.6f);  // Adjusted for smoother gain changes
}

float AGC::smoothGain(float new_gain) {
    float time_constant = (new_gain > gain) ? attack_time * 0.25f : release_time * 0.5f;
    float alpha = 1.0f - std::exp(-1.0f / (time_constant * sample_rate));
    return gain + alpha * (new_gain - gain);
}

void AGC::process(float *arr, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        lookahead_buffer.push_back(std::abs(arr[i]));
        float current_peak = *std::max_element(lookahead_buffer.begin(), lookahead_buffer.end());
        
        level_history.push_back(current_peak);
        level_history.erase(level_history.begin());
        
        float short_term_level = *std::max_element(level_history.end() - std::min(level_history.size(), size_t(sample_rate * 0.01f)), level_history.end());
        float long_term_level = *std::max_element(level_history.begin(), level_history.end());
        
        // Adaptive averaging
        average_level = 0.9f * average_level + 0.1f * (0.7f * short_term_level + 0.3f * long_term_level);
        
        float target_gain = computeGain(average_level);
        target_gain = std::clamp(target_gain, min_gain, max_gain);
        
        gain = smoothGain(target_gain);
        
        float processed_sample = arr[i] * gain;
        
        // Improved soft knee limiter
        const float threshold = 0.9f;
        const float knee_width = 0.1f;
        if (std::abs(processed_sample) > (threshold - knee_width / 2)) {
            float knee_factor = (std::abs(processed_sample) - (threshold - knee_width / 2)) / knee_width;
            knee_factor = std::min(1.0f, knee_factor);
            float compression = 1.0f + knee_factor * knee_factor * (1.0f / (1.0f - threshold) - 1.0f);
            processed_sample /= compression;
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