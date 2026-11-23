package com.example.audioshare

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.Executors

class LivePlayback {
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "audioshare-playback").apply { isDaemon = true }
    }
    private var track: AudioTrack? = null

    fun start(sampleRate: Int) {
        val rate = sampleRate.takeIf { it in 8000..96000 } ?: DEFAULT_SAMPLE_RATE
        worker.execute {
            releaseTrack()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(rate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                .build()
            val minBuffer = AudioTrack.getMinBufferSize(
                rate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            val player = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(format)
                .setBufferSizeInBytes(maxOf(minBuffer, rate / 2))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            if (player.state == AudioTrack.STATE_INITIALIZED) {
                track = player
                player.play()
            } else {
                player.release()
            }
        }
    }

    fun write(pcm: ByteArray, silenceMs: Int, reset: Boolean) {
        val bytes = pcm.copyOf()
        worker.execute {
            val player = track ?: return@execute
            if (reset) {
                player.pause()
                player.flush()
                player.play()
            }
            val silenceBytes = (player.sampleRate.toLong() * BYTES_PER_FRAME * silenceMs.coerceIn(0, 1000) / 1000)
                .toInt()
            if (silenceBytes > 0) writeFully(player, ByteArray(silenceBytes))
            writeFully(player, bytes)
        }
    }

    fun setVolume(volume: Float) {
        val level = volume.coerceIn(0f, 1f)
        worker.execute { track?.setVolume(level) }
    }

    fun stop() {
        worker.execute { releaseTrack() }
    }

    private fun writeFully(player: AudioTrack, bytes: ByteArray) {
        var offset = 0
        while (offset < bytes.size) {
            val written = player.write(bytes, offset, bytes.size - offset, AudioTrack.WRITE_BLOCKING)
            if (written <= 0) return
            offset += written
        }
    }

    private fun releaseTrack() {
        track?.let { player ->
            try {
                player.pause()
                player.flush()
            } catch (_: IllegalStateException) {
            }
            player.release()
        }
        track = null
    }

    private companion object {
        const val DEFAULT_SAMPLE_RATE = 48000
        const val BYTES_PER_FRAME = 4
    }
}
