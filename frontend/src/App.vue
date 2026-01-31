<template>
  <div class="app">
    <header class="header">
      <h1>Qwen3-TTS 语音合成</h1>
      <p class="subtitle">基于通义千问的文本转语音服务</p>
    </header>

    <main class="main">
      <!-- 状态指示 -->
      <div class="status-bar" :class="statusClass">
        <span class="status-dot"></span>
        <span>{{ statusText }}</span>
      </div>

      <!-- 输入区域 -->
      <div class="input-section">
        <label for="text-input">输入文本</label>
        <textarea
          id="text-input"
          v-model="text"
          placeholder="请输入要转换为语音的文本..."
          rows="6"
          :disabled="loading"
        ></textarea>
        <div class="char-count">{{ text.length }} / 5000</div>
      </div>

      <!-- 语言选择 -->
      <div class="options-section">
        <label for="language-select">选择语言</label>
        <select id="language-select" v-model="language" :disabled="loading">
          <option v-for="lang in languages" :key="lang" :value="lang">
            {{ languageNames[lang] || lang }}
          </option>
        </select>
      </div>

      <!-- 说话人选择 -->
      <div class="options-section">
        <label for="speaker-select">选择声音</label>
        <select id="speaker-select" v-model="speaker" :disabled="loading">
          <option v-for="(desc, name) in speakers" :key="name" :value="name">
            {{ name }} - {{ desc }}
          </option>
        </select>
      </div>

      <!-- 生成按钮 -->
      <button
        class="generate-btn"
        @click="generateSpeech"
        :disabled="!canGenerate"
      >
        <span v-if="loading" class="spinner"></span>
        <span v-else>生成语音</span>
      </button>

      <!-- 结果区域 -->
      <div v-if="audioUrl" class="result-section">
        <h3>生成结果</h3>
        <audio ref="audioPlayer" :src="audioUrl" controls></audio>
        <div class="audio-info">
          <span>时长: {{ duration }}秒</span>
          <button class="download-btn" @click="downloadAudio">下载音频</button>
        </div>
      </div>

      <!-- 错误提示 -->
      <div v-if="error" class="error-message">
        {{ error }}
      </div>

      <!-- 历史记录 -->
      <div v-if="history.length > 0" class="history-section">
        <h3>历史记录</h3>
        <div class="history-list">
          <div v-for="item in history" :key="item.id" class="history-item">
            <p class="history-text">{{ truncateText(item.text) }}</p>
            <div class="history-actions">
              <audio :src="item.url" controls></audio>
              <button class="delete-btn" @click="deleteAudio(item.id)">删除</button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <footer class="footer">
      <p>Powered by Qwen3-TTS-0.6B | CPU Mode</p>
    </footer>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'App',
  data() {
    return {
      text: '',
      language: 'Chinese',
      speaker: 'Vivian',
      languages: [],
      speakers: {},
      loading: false,
      audioUrl: null,
      audioId: null,
      duration: null,
      error: null,
      serverStatus: null,
      history: [],
      languageNames: {
        'Chinese': '中文',
        'English': '英语',
        'Japanese': '日语',
        'Korean': '韩语',
        'German': '德语',
        'French': '法语',
        'Russian': '俄语',
        'Portuguese': '葡萄牙语',
        'Spanish': '西班牙语',
        'Italian': '意大利语',
      }
    }
  },
  computed: {
    canGenerate() {
      return this.text.trim().length > 0 && !this.loading && this.serverStatus?.model_loaded
    },
    statusText() {
      if (!this.serverStatus) return '正在连接服务器...'
      if (!this.serverStatus.model_loaded) return '模型加载中...'
      return `服务就绪 (${this.serverStatus.device.toUpperCase()})`
    },
    statusClass() {
      if (!this.serverStatus) return 'status-connecting'
      if (!this.serverStatus.model_loaded) return 'status-loading'
      return 'status-ready'
    }
  },
  async mounted() {
    await this.fetchStatus()
    await this.fetchLanguages()
    await this.fetchSpeakers()
    // 定时检查状态
    setInterval(this.fetchStatus, 10000)
  },
  methods: {
    async fetchStatus() {
      try {
        const res = await axios.get('/api/status')
        this.serverStatus = res.data
      } catch (e) {
        this.serverStatus = null
      }
    },
    async fetchLanguages() {
      try {
        const res = await axios.get('/api/languages')
        this.languages = res.data.languages
      } catch (e) {
        this.languages = ['Chinese', 'English']
      }
    },
    async fetchSpeakers() {
      try {
        const res = await axios.get('/api/speakers')
        this.speakers = res.data.speakers
      } catch (e) {
        this.speakers = { 'Vivian': '默认声音' }
      }
    },
    async generateSpeech() {
      if (!this.canGenerate) return

      this.loading = true
      this.error = null
      this.audioUrl = null

      try {
        const res = await axios.post('/api/tts', {
          text: this.text,
          language: this.language,
          speaker: this.speaker,
        })

        if (res.data.success) {
          this.audioUrl = res.data.audio_url
          this.audioId = res.data.audio_id
          this.duration = res.data.duration

          // 添加到历史记录
          this.history.unshift({
            id: res.data.audio_id,
            text: this.text,
            url: res.data.audio_url,
          })

          // 最多保留 10 条
          if (this.history.length > 10) {
            this.history.pop()
          }
        } else {
          this.error = res.data.message
        }
      } catch (e) {
        this.error = e.response?.data?.detail || '生成失败，请稍后重试'
      } finally {
        this.loading = false
      }
    },
    async deleteAudio(audioId) {
      try {
        await axios.delete(`/api/audio/${audioId}`)
        this.history = this.history.filter(item => item.id !== audioId)
        if (this.audioId === audioId) {
          this.audioUrl = null
          this.audioId = null
        }
      } catch (e) {
        console.error('删除失败:', e)
      }
    },
    downloadAudio() {
      if (!this.audioUrl) return
      const a = document.createElement('a')
      a.href = this.audioUrl
      a.download = `tts_${this.audioId}.wav`
      a.click()
    },
    truncateText(text) {
      return text.length > 50 ? text.slice(0, 50) + '...' : text
    }
  }
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  min-height: 100vh;
}

.header {
  text-align: center;
  padding: 40px 0;
  color: white;
}

.header h1 {
  font-size: 2.5rem;
  margin-bottom: 10px;
}

.subtitle {
  opacity: 0.9;
  font-size: 1.1rem;
}

.main {
  background: white;
  border-radius: 16px;
  padding: 30px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
}

.status-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 24px;
  font-size: 0.9rem;
}

.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.status-connecting {
  background: #fef3cd;
  color: #856404;
}
.status-connecting .status-dot {
  background: #ffc107;
  animation: pulse 1.5s infinite;
}

.status-loading {
  background: #cce5ff;
  color: #004085;
}
.status-loading .status-dot {
  background: #007bff;
  animation: pulse 1.5s infinite;
}

.status-ready {
  background: #d4edda;
  color: #155724;
}
.status-ready .status-dot {
  background: #28a745;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.input-section {
  margin-bottom: 20px;
}

.input-section label,
.options-section label {
  display: block;
  margin-bottom: 8px;
  font-weight: 600;
  color: #333;
}

textarea {
  width: 100%;
  padding: 16px;
  border: 2px solid #e0e0e0;
  border-radius: 12px;
  font-size: 1rem;
  resize: vertical;
  transition: border-color 0.2s;
}

textarea:focus {
  outline: none;
  border-color: #667eea;
}

.char-count {
  text-align: right;
  font-size: 0.85rem;
  color: #888;
  margin-top: 6px;
}

.options-section {
  margin-bottom: 24px;
}

select {
  width: 100%;
  padding: 14px 16px;
  border: 2px solid #e0e0e0;
  border-radius: 12px;
  font-size: 1rem;
  background: white;
  cursor: pointer;
}

select:focus {
  outline: none;
  border-color: #667eea;
}

.generate-btn {
  width: 100%;
  padding: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 12px;
  font-size: 1.1rem;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.generate-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(102, 126, 234, 0.4);
}

.generate-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  width: 20px;
  height: 20px;
  border: 3px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.result-section {
  margin-top: 30px;
  padding: 24px;
  background: #f8f9fa;
  border-radius: 12px;
}

.result-section h3 {
  margin-bottom: 16px;
  color: #333;
}

audio {
  width: 100%;
  margin-bottom: 12px;
}

.audio-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.download-btn {
  padding: 10px 20px;
  background: #28a745;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 500;
  transition: background 0.2s;
}

.download-btn:hover {
  background: #218838;
}

.error-message {
  margin-top: 20px;
  padding: 16px;
  background: #f8d7da;
  color: #721c24;
  border-radius: 8px;
}

.history-section {
  margin-top: 30px;
  border-top: 1px solid #e0e0e0;
  padding-top: 24px;
}

.history-section h3 {
  margin-bottom: 16px;
  color: #333;
}

.history-item {
  padding: 16px;
  background: #f8f9fa;
  border-radius: 8px;
  margin-bottom: 12px;
}

.history-text {
  margin-bottom: 12px;
  color: #555;
  font-size: 0.95rem;
}

.history-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.history-actions audio {
  flex: 1;
  margin-bottom: 0;
}

.delete-btn {
  padding: 8px 16px;
  background: #dc3545;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.9rem;
}

.delete-btn:hover {
  background: #c82333;
}

.footer {
  text-align: center;
  padding: 30px;
  color: rgba(255, 255, 255, 0.8);
  font-size: 0.9rem;
}
</style>
