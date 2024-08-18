#ifndef AUDIO_PROCESSING_H
#define AUDIO_PROCESSING_H

#include <cstddef>
#include <deque>
#include <vector>
#include <cmath>

class AGC {
private:
    float sample_rate;
    float target_level;
    float attack_time;
    float release_time;
    size_t look_ahead_samples;
    float gain;
    float max_gain;
    float min_gain;
    float average_level;
    
    std::deque<float> lookahead_buffer;
    std::vector<float> level_history;

    float computeGain(float input_level);
    float smoothGain(float new_gain);

public:
    AGC(float targetLevelDb = -3.0f, float attackTimeMs = 5.0f,
        float releaseTimeMs = 50.0f, float lookAheadTimeMs = 5.0f,
        float sr = 44100.0f);
    void process(float *arr, size_t len);
    void reset();
    

    float getGain() const { return gain; }
    float getAverageLevel() const { return average_level; }
    

    void setTargetLevel(float targetLevelDb) { target_level = std::pow(10.0f, targetLevelDb / 20.0f); }
    void setAttackTime(float attackTimeMs) { attack_time = attackTimeMs / 1000.0f; }
    void setReleaseTime(float releaseTimeMs) { release_time = releaseTimeMs / 1000.0f; }
};

#endif // AUDIO_PROCESSING_H