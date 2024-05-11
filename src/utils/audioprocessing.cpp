#include "audioprocessing.h"
#include <cmath>
#include <algorithm>

AGC::AGC(float desiredLevel, float attackTimeMs, float releaseTimeMs, float lookAheadTimeMs, float sr)
    : desired_level(desiredLevel), sample_rate(sr), last_gain(1.0f), peak_1(0), peak_2(0) {
    look_ahead_samples = static_cast<size_t>(lookAheadTimeMs * sample_rate / 1000.0f);
}

void AGC::push(float sample) {
    lookahead_buffer.push_back(sample);
    if (lookahead_buffer.size() > look_ahead_samples) {
        this->pop();
    }
}

void AGC::pop() {
    // Calculate the peak value of the lookahead buffer
    float peak_input = 0;
    for (float sample : lookahead_buffer) {
        float val = std::abs(sample);
        if (val > peak_input) {
            peak_input = val;
        }
    }

    // Determine the maximal peak out of the current and previous blocks
    if (peak_input > peak_1) peak_1 = peak_input;
    if (peak_1 > peak_2) peak_2 = peak_1;

    lookahead_buffer.clear();
}

float AGC::max() { return peak_2; }

void AGC::process(float *arr, size_t len) {
    const size_t block_size = 3; // Block size for processing
    for (size_t i = 0; i < len; i += block_size) {
        size_t block_end = std::min(i + block_size, len);

        // Calculate the peak value of the current block
        float target_peak = 0;
        for (size_t j = i; j < block_end; ++j) {
            float sample_abs = std::abs(arr[j]);
            if (sample_abs > target_peak) {
                target_peak = sample_abs;
            }
        }

        // Determine the maximal peak out of the current and previous blocks
        if (target_peak > peak_1) peak_1 = target_peak;
        if (peak_1 > peak_2) peak_2 = peak_1;

        // Calculate the target gain
        float target_gain = desired_level / peak_2;


        // Limit the target gain to prevent excessive amplification
        if (target_gain > 1000) target_gain = 1000;

        target_gain *= 3.f; // Increase by 20%


        // Apply gain to the current block
        for (size_t j = i; j < block_end; ++j) {
            arr[j] *= target_gain;
        }

        // Update the state for the next block
        last_gain = target_gain;
    }
}

void AGC::reset() {
    peak_1 = 0;
    peak_2 = 0;
}
