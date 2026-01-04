import Flutter
import UIKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set up audio session: \(error)")
    }
    
    setupRemoteCommandCenter()
    setupMethodChannel()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func setupMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: "com.example.kconnectMobile/audio", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "updateNowPlaying":
        self?.updateNowPlayingInfo(call: call)
        result(nil)
      case "updateCommandAvailability":
        self?.updateCommandAvailability(call: call)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  func updateCommandAvailability(call: FlutterMethodCall) {
    guard let args = call.arguments as? [String: Any] else { return }
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.nextTrackCommand.isEnabled = args["canGoNext"] as? Bool ?? false
    commandCenter.previousTrackCommand.isEnabled = args["canGoPrevious"] as? Bool ?? false
  }
  
  func updateNowPlayingInfo(call: FlutterMethodCall) {
    guard let args = call.arguments as? [String: Any] else { return }
    let title = args["title"] as? String ?? ""
    let artist = args["artist"] as? String ?? ""
    let duration = args["duration"] as? Int ?? 0
    let position = args["position"] as? Int ?? 0
    let isPlaying = args["isPlaying"] as? Bool ?? false
    let artworkUrl = args["artwork"] as? String
    var nowPlayingInfo = [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(duration) / 1000.0
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(position) / 1000.0
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    if let artworkUrlString = artworkUrl, let artworkUrl = URL(string: artworkUrlString) {
      URLSession.shared.dataTask(with: artworkUrl) { data, _, _ in
        if let data = data, let image = UIImage(data: data) {
          let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
          nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
      }.resume()
    } else {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
  }
  
  func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()
    let channelName = "com.example.kconnectMobile/audio"
    
    commandCenter.playCommand.addTarget { [weak self] _ in
      if let controller = self?.window?.rootViewController as? FlutterViewController {
        FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          .invokeMethod("resume", arguments: nil)
      }
      return .success
    }
    
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      if let controller = self?.window?.rootViewController as? FlutterViewController {
        FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          .invokeMethod("pause", arguments: nil)
      }
      return .success
    }
    
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      if let controller = self?.window?.rootViewController as? FlutterViewController {
        FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          .invokeMethod("toggle", arguments: nil)
      }
      return .success
    }
    
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      if let controller = self?.window?.rootViewController as? FlutterViewController {
        FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          .invokeMethod("handleNextTrack", arguments: nil)
      }
      return .success
    }
    
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      if let controller = self?.window?.rootViewController as? FlutterViewController {
        FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          .invokeMethod("handlePreviousTrack", arguments: nil)
      }
      return .success
    }
    
    commandCenter.skipForwardCommand.preferredIntervals = [15]
    commandCenter.skipForwardCommand.isEnabled = true
    commandCenter.skipForwardCommand.addTarget { [weak self] event in
      guard let skipEvent = event as? MPSkipIntervalCommandEvent,
            let controller = self?.window?.rootViewController as? FlutterViewController else {
        return .commandFailed
      }
      FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        .invokeMethod("seekForward", arguments: skipEvent.interval)
      return .success
    }
    
    commandCenter.skipBackwardCommand.preferredIntervals = [15]
    commandCenter.skipBackwardCommand.isEnabled = true
    commandCenter.skipBackwardCommand.addTarget { [weak self] event in
      guard let skipEvent = event as? MPSkipIntervalCommandEvent,
            let controller = self?.window?.rootViewController as? FlutterViewController else {
        return .commandFailed
      }
      FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        .invokeMethod("seekBackward", arguments: skipEvent.interval)
      return .success
    }
    
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
            let controller = self?.window?.rootViewController as? FlutterViewController else {
        return .commandFailed
      }
      FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        .invokeMethod("seekTo", arguments: Int(positionEvent.positionTime * 1000))
      return .success
    }
  }
}
