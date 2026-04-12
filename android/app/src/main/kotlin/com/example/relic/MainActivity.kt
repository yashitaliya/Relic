package com.example.relic

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.relic/saf"
    private val SECURE_CHANNEL = "com.example.relic/secure"
    private val OPEN_DOCUMENT_TREE_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Secure Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "secure") {
                val secure = call.argument<Boolean>("secure") ?: false
                if (secure) {
                    window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            } else if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    android.media.MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                    result.success(null)
                } else {
                    result.error("INVALID_PATH", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // SAF Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDocumentTree" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    startActivityForResult(intent, OPEN_DOCUMENT_TREE_REQUEST_CODE)
                }
                "getPersistedUri" -> {
                    val uriStr = getPersistedUri()
                    result.success(uriStr)
                }
                "releasePersistedUri" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        try {
                            val uri = Uri.parse(uriStr)
                            contentResolver.releasePersistableUriPermission(uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            savePersistedUri(null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("RELEASE_FAILED", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "createFolder" -> {
                    val name = call.argument<String>("name")
                    if (name != null) {
                        val success = createFolder(name)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Name is required", null)
                    }
                }
                "renameFolder" -> {
                    val oldName = call.argument<String>("oldName")
                    val newName = call.argument<String>("newName")
                    if (oldName != null && newName != null) {
                        val success = renameFolder(oldName, newName)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Old and new names are required", null)
                    }
                }
                "renameFile" -> {
                    val folder = call.argument<String>("folder")
                    val oldName = call.argument<String>("oldName")
                    val newName = call.argument<String>("newName")
                    if (folder != null && oldName != null && newName != null) {
                        val success = renameFile(folder, oldName, newName)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Folder, old name, and new name are required", null)
                    }
                }
                "copyFile" -> {
                    val sourceUri = call.argument<String>("sourceUri")
                    val targetFolder = call.argument<String>("targetFolder")
                    val targetName = call.argument<String>("targetName")
                    if (sourceUri != null && targetFolder != null && targetName != null) {
                        val success = copyFile(sourceUri, targetFolder, targetName)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Source URI, target folder, and target name are required", null)
                    }
                }
                "deleteFile" -> {
                    val folder = call.argument<String>("folder")
                    val name = call.argument<String>("name")
                    if (folder != null && name != null) {
                        val success = deleteFile(folder, name)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Folder and name are required", null)
                    }
                }
                "deleteFileByPath" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val success = deleteFileByPath(path)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Path is required", null)
                    }
                }
                "requestAllFilesAccess" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                            intent.addCategory("android.intent.category.DEFAULT")
                            intent.data = Uri.parse(String.format("package:%s", applicationContext.packageName))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            val intent = Intent()
                            intent.action = android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
                            startActivity(intent)
                            result.success(true)
                        }
                    } else {
                        result.success(true) // Not needed below Android 11
                    }
                }
                "checkAllFilesAccess" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        result.success(android.os.Environment.isExternalStorageManager())
                    } else {
                        result.success(true) // Always true below Android 11 (legacy storage)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_DOCUMENT_TREE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri = data.data
                if (uri != null) {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    savePersistedUri(uri.toString())
                    pendingResult?.success(uri.toString())
                } else {
                    pendingResult?.error("URI_NULL", "Failed to get URI", null)
                }
            } else {
                pendingResult?.error("CANCELED", "User canceled", null)
            }
            pendingResult = null
        }
    }

    private fun getPersistedUri(): String? {
        val prefs = getSharedPreferences("SAF_PREFS", MODE_PRIVATE)
        return prefs.getString("root_uri", null)
    }

    private fun savePersistedUri(uri: String?) {
        val prefs = getSharedPreferences("SAF_PREFS", MODE_PRIVATE)
        prefs.edit().putString("root_uri", uri).apply()
    }

    private fun getRootDocumentFile(): DocumentFile? {
        val uriStr = getPersistedUri() ?: return null
        return DocumentFile.fromTreeUri(this, Uri.parse(uriStr))
    }

    // Helper to find a directory inside the root (or root itself if name is empty/null)
    private fun findDirectory(name: String): DocumentFile? {
        val root = getRootDocumentFile() ?: return null
        if (name.isEmpty() || name == "/") return root
        
        // Handle nested paths (e.g. "DCIM/Camera")
        val parts = name.split("/")
        var currentDir = root
        
        for (part in parts) {
            if (part.isEmpty()) continue
            val nextDir = currentDir.findFile(part)
            if (nextDir != null && nextDir.isDirectory) {
                currentDir = nextDir
            } else {
                return null // Path not found
            }
        }
        
        return currentDir
    }

    // Helper to check for All Files Access
    private fun hasAllFilesAccess(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            android.os.Environment.isExternalStorageManager()
        } else {
            true // Legacy storage
        }
    }

    // Helper to get the base directory (Pictures) when using All Files Access
    private fun getBaseDirectory(): java.io.File {
        return android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_PICTURES)
    }

    private fun createFolder(name: String): Boolean {
        if (hasAllFilesAccess()) {
            val base = getBaseDirectory()
            val folder = java.io.File(base, name)
            if (folder.exists()) return true
            return folder.mkdirs()
        }
        
        val root = getRootDocumentFile() ?: return false
        if (root.findFile(name) != null) return true
        return root.createDirectory(name) != null
    }

    private fun renameFolder(oldName: String, newName: String): Boolean {
        if (hasAllFilesAccess()) {
            val base = getBaseDirectory()
            val oldFolder = java.io.File(base, oldName)
            val newFolder = java.io.File(base, newName)
            if (!oldFolder.exists()) return false
            if (newFolder.exists()) return false
            return oldFolder.renameTo(newFolder)
        }

        val root = getRootDocumentFile() ?: return false
        val folder = root.findFile(oldName) ?: return false
        if (root.findFile(newName) != null) return false
        return folder.renameTo(newName)
    }

    private fun renameFile(folderName: String, oldName: String, newName: String): Boolean {
        if (hasAllFilesAccess()) {
            val base = getBaseDirectory()
            // Handle nested paths in folderName
            val folder = java.io.File(base, folderName)
            if (!folder.exists()) return false
            
            val oldFile = java.io.File(folder, oldName)
            val newFile = java.io.File(folder, newName)
            
            if (!oldFile.exists()) return false
            if (newFile.exists()) return false
            
            val success = oldFile.renameTo(newFile)
            if (success) {
                // Scan both old (to remove) and new (to add)
                android.media.MediaScannerConnection.scanFile(this, arrayOf(oldFile.absolutePath, newFile.absolutePath), null, null)
            }
            return success
        }

        val folder = findDirectory(folderName) ?: return false
        val file = folder.findFile(oldName) ?: return false
        if (folder.findFile(newName) != null) return false // Target exists
        return file.renameTo(newName)
    }

    private fun copyFile(sourceUriStr: String, targetFolderName: String, targetFileName: String): Boolean {
        if (hasAllFilesAccess()) {
            try {
                val base = getBaseDirectory()
                val targetDir = java.io.File(base, targetFolderName)
                if (!targetDir.exists()) {
                    targetDir.mkdirs()
                }
                
                // Ensure unique name
                var finalName = targetFileName
                var destFile = java.io.File(targetDir, finalName)
                if (destFile.exists()) {
                    val nameWithoutExt = targetFileName.substringBeforeLast(".")
                    val ext = targetFileName.substringAfterLast(".", "")
                    finalName = "${nameWithoutExt}_${System.currentTimeMillis()}.$ext"
                    destFile = java.io.File(targetDir, finalName)
                }
                
                val sourceUri = Uri.parse(sourceUriStr)
                val inputStream = contentResolver.openInputStream(sourceUri) ?: return false
                val outputStream = java.io.FileOutputStream(destFile)
                
                inputStream.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }
                
                android.media.MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), null, null)
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        val root = getRootDocumentFile() ?: return false
        
        // Find or create target directory
        // We use findDirectory to support nested paths
        var targetDir = findDirectory(targetFolderName)
        if (targetDir == null) {
            // If not found, try to create it. 
            // Note: simple createDirectory only works for single level. 
            // If targetFolderName is nested and doesn't exist, we might need recursive creation.
            // For now, assuming single level or existing nested.
            // Fallback to create in root if find failed (likely single level)
            targetDir = root.createDirectory(targetFolderName)
        }
        
        if (targetDir == null) return false
        
        try {
            val sourceUri = Uri.parse(sourceUriStr)
            val mimeType = contentResolver.getType(sourceUri) ?: "image/jpeg"
            
            // Ensure unique name
            var finalName = targetFileName
            if (targetDir.findFile(finalName) != null) {
                val nameWithoutExt = targetFileName.substringBeforeLast(".")
                val ext = targetFileName.substringAfterLast(".", "")
                finalName = "${nameWithoutExt}_${System.currentTimeMillis()}.$ext"
            }
            
            val destFile = targetDir.createFile(mimeType, finalName) ?: return false
            
            val inputStream: InputStream? = contentResolver.openInputStream(sourceUri)
            val outputStream: OutputStream? = contentResolver.openOutputStream(destFile.uri)
            
            if (inputStream != null && outputStream != null) {
                inputStream.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }
                // Scan the new file
                android.media.MediaScannerConnection.scanFile(this, arrayOf(destFile.uri.toString()), null, null)
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun deleteFile(folderName: String, name: String): Boolean {
        if (hasAllFilesAccess()) {
            val base = getBaseDirectory()
            val folder = java.io.File(base, folderName)
            if (!folder.exists()) return false
            
            val file = java.io.File(folder, name)
            if (!file.exists()) return false
            
            val success = file.delete()
            if (success) {
                android.media.MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), null, null)
            }
            return success
        }

        val folder = findDirectory(folderName) ?: return false
        val file = folder.findFile(name) ?: return false
        return file.delete()
    }

    private fun deleteFileByPath(path: String): Boolean {
        val file = java.io.File(path)
        if (file.exists()) {
            val success = file.delete()
            if (success) {
                android.media.MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), null, null)
            }
            return success
        }
        return false
    }
}
