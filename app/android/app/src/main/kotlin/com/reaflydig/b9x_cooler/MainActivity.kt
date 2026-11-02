package com.reaflydig.b9x_cooler

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.reaflydig.b9x/ble"
        private const val EVENT_CHANNEL = "com.reaflydig.b9x/events"
        private const val REQ_PERMISSIONS = 0x6B39

        private val SERVICE_UUID: UUID =
            UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
        private val WRITE_UUID: UUID =
            UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
        private val NOTIFY_UUID: UUID =
            UUID.fromString("0000ffe4-0000-1000-8000-00805f9b34fb")
        private val CCCD_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null

    private val bluetoothManager: BluetoothManager?
        get() = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private val adapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var notifyChar: BluetoothGattCharacteristic? = null
    private var scanCallback: ScanCallback? = null
    private var scanning = false

    private var pendingAfterPermission: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureReady" -> result.success(ensurePermissions())
                    "startScan" -> {
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        if (!ensurePermissions()) {
                            result.success(false)
                        } else {
                            startScan(names)
                            result.success(true)
                        }
                    }
                    "stopScan" -> {
                        stopScan()
                        result.success(null)
                    }
                    "connect" -> {
                        val id = call.argument<String>("id")
                        if (id == null) {
                            result.error("BAD_ARGS", "id required", null)
                        } else {
                            result.success(connect(id))
                        }
                    }
                    "disconnect" -> {
                        disconnect()
                        result.success(null)
                    }
                    "write" -> {
                        val bytes = call.argument<List<Int>>("bytes")
                        if (bytes == null) {
                            result.error("BAD_ARGS", "bytes required", null)
                        } else {
                            enqueueWrite(bytes.map { it.toByte() }.toByteArray())
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    // ---------------------------------------------------------------- 权限

    private fun requiredPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasPermissions(): Boolean = requiredPermissions().all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensurePermissions(): Boolean {
        if (hasPermissions()) return true
        ActivityCompat.requestPermissions(this, requiredPermissions(), REQ_PERMISSIONS)
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_PERMISSIONS) {
            val ok = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            emit(mapOf("type" to "permission", "state" to if (ok) "granted" else "denied"))
            pendingAfterPermission?.takeIf { ok }?.invoke()
            pendingAfterPermission = null
        }
    }

    // ---------------------------------------------------------------- 扫描

    private fun startScan(names: List<String>) {
        val btAdapter = adapter ?: run {
            emit(mapOf("type" to "error", "message" to "蓝牙不可用"))
            return
        }
        if (!btAdapter.isEnabled) {
            emit(mapOf("type" to "error", "message" to "请先打开蓝牙"))
            return
        }
        if (scanning) stopScan()

        val scanner = btAdapter.bluetoothLeScanner ?: run {
            emit(mapOf("type" to "error", "message" to "设备不支持 BLE"))
            return
        }
        val wanted = names.map { it.lowercase() }
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val name = try {
                    result.scanRecord?.deviceName ?: result.device.name
                } catch (e: SecurityException) {
                    null
                } ?: return
                if (wanted.isNotEmpty() && wanted.none { name.lowercase().startsWith(it) }) return
                emit(
                    mapOf(
                        "type" to "scanResult",
                        "device" to mapOf(
                            "id" to result.device.address,
                            "name" to name,
                            "rssi" to result.rssi,
                        ),
                    ),
                )
            }

            override fun onScanFailed(errorCode: Int) {
                emit(mapOf("type" to "error", "message" to "扫描失败 $errorCode"))
            }
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanCallback = callback
        scanning = true
        emit(mapOf("type" to "connection", "state" to "scanning"))
        scanner.startScan(null, settings, callback)
    }

    private fun stopScan() {
        if (!scanning) return
        scanning = false
        val scanner = adapter?.bluetoothLeScanner
        scanCallback?.let {
            try {
                scanner?.stopScan(it)
            } catch (_: SecurityException) {
            }
        }
        scanCallback = null
        emit(mapOf("type" to "connection", "state" to "idle"))
    }

    // ---------------------------------------------------------------- 连接

    private fun connect(address: String): Boolean {
        val btAdapter = adapter ?: return false
        val device: BluetoothDevice = try {
            btAdapter.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            emit(mapOf("type" to "error", "message" to "无效地址"))
            return false
        }
        stopScan()
        disconnect()
        emit(mapOf("type" to "connection", "state" to "connecting"))
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(this, false, gattCallback, BluetoothDevice.TRANSPORT_LE, BluetoothDevice.PHY_LE_2M)
        } else {
            device.connectGatt(this, false, gattCallback)
        }
        return true
    }

    private fun disconnect() {
        synchronized(writeQueue) { writeQueue.clear() }
        writing = false
        gatt?.let {
            try {
                it.disconnect()
                it.close()
            } catch (_: SecurityException) {
            }
        }
        gatt = null
        writeChar = null
        notifyChar = null
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    g.discoverServices()
                } catch (_: SecurityException) {
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                emit(mapOf("type" to "connection", "state" to "disconnected"))
                writeChar = null
                notifyChar = null
                try {
                    g.close()
                } catch (_: SecurityException) {
                }
                if (gatt === g) gatt = null
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val service = g.getService(SERVICE_UUID) ?: run {
                emit(mapOf("type" to "error", "message" to "未找到 FFE0 服务"))
                return
            }
            writeChar = service.getCharacteristic(WRITE_UUID)
            notifyChar = service.getCharacteristic(NOTIFY_UUID)
            try {
                writeChar?.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                val nc = notifyChar ?: return
                g.setCharacteristicNotification(nc, true)
                val descriptor = nc.getDescriptor(CCCD_UUID)
                if (descriptor != null) {
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    g.writeDescriptor(descriptor)
                }
                // 主动读一次，促使设备立刻回报当前状态（首帧更快）。
                g.readCharacteristic(nc)
            } catch (_: SecurityException) {
            }
            emit(
                mapOf(
                    "type" to "connection",
                    "state" to "connected",
                    "device" to mapOf(
                        "id" to g.device.address,
                        "name" to (try {
                            g.device.name
                        } catch (e: SecurityException) {
                            null
                        } ?: "Flydigi B9X"),
                    ),
                ),
            )
        }

        override fun onCharacteristicWrite(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            // GATT 写完成，解锁队列继续发下一条（比固定延迟更精准）。
            writing = false
            drainWrites()
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                characteristic.value?.let { emitData(it) }
            }
        }

        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            emitData(value)
        }
    }

    private fun emitData(value: ByteArray) {
        emit(
            mapOf(
                "type" to "data",
                "bytes" to value.map { it.toInt() and 0xFF },
            ),
        )
    }

    // ---------------------------------------------------------------- 写入

    private val writeQueue = ArrayDeque<ByteArray>()
    private var writing = false

    /// 串行写队列：Android 的 GATT 同一时刻只允许一个 outstanding 写操作，
    /// 拖滑杆时并发写会大量返回 false（表现为“调了没反应”）。
    private fun enqueueWrite(bytes: ByteArray) {
        synchronized(writeQueue) { writeQueue.addLast(bytes) }
        drainWrites()
    }

    private fun drainWrites() {
        mainHandler.post {
            var next: ByteArray? = null
            synchronized(writeQueue) {
                if (writing || writeQueue.isEmpty()) return@post
                next = writeQueue.removeFirst()
                writing = true
            }
            val bytes = next ?: return@post
            if (!writeNow(bytes)) {
                synchronized(writeQueue) { writeQueue.addFirst(bytes) }
                mainHandler.postDelayed({
                    writing = false
                    drainWrites()
                }, 120)
                return@post
            }
            mainHandler.postDelayed({
                writing = false
                drainWrites()
            }, 60)
        }
    }

    private fun writeNow(bytes: ByteArray): Boolean {
        val g = gatt ?: return false
        val c = writeChar ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                g.writeCharacteristic(c, bytes, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) ==
                    BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                @Suppress("DEPRECATION")
                c.value = bytes
                @Suppress("DEPRECATION")
                g.writeCharacteristic(c)
            }
        } catch (e: SecurityException) {
            false
        }
    }

    // ---------------------------------------------------------------- 事件

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { events?.success(event) }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onDestroy() {
        stopScan()
        disconnect()
        super.onDestroy()
    }
}

private object BluetoothStatusCodes {
    const val SUCCESS = 0
}
