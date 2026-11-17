//
//  RemoteControlService.swift
//  Pelagica
//

import Combine
import Foundation
import JellyfinAPI

@MainActor
final class RemoteControlService: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let header: String?
        let text: String?
        let duration: Duration
    }

    @Published var message: Message?

    private weak var activePlayback: PlaybackSession?
    private var socket: JellyfinSocket.Session?
    private var listenTask: Task<Void, Never>?

    private static let defaultMessageDuration: Duration = .seconds(5)

    // MARK: - Connection

    func connect(client: JellyfinClient) {
        disconnect()
        let socket = client.socket(
            supportsMediaControl: true,
            supportedCommands: [.displayMessage]
        ).connect()
        self.socket = socket

        listenTask = Task { [weak self] in
            do {
                for try await event in socket.events {
                    guard case let .message(message) = event else { continue }
                    self?.handle(message)
                }
            } catch {
                print("Pelagica remote control: socket ended: \(error)")
            }
        }
    }

    func disconnect() {
        listenTask?.cancel()
        listenTask = nil
        socket?.disconnect()
        socket = nil
        message = nil
    }

    // MARK: - Active player

    func register(_ session: PlaybackSession) {
        activePlayback = session
    }

    func unregister(_ session: PlaybackSession) {
        if activePlayback === session {
            activePlayback = nil
        }
    }

    // MARK: - Commands

    private func handle(_ message: OutboundWebSocketMessage) {
        switch message {
        case let .playstateMessage(message):
            switch message.data?.command {
            case .playPause: activePlayback?.controller.togglePlayPause()
            case .stop: activePlayback?.close()
            default: break
            }
        case let .generalCommandMessage(message):
            if message.data?.name == .displayMessage {
                showMessage(message.data?.arguments ?? [:])
            }
        default:
            break
        }
    }

    private func showMessage(_ arguments: [String: String]) {
        let header = arguments["Header"].flatMap { $0.isEmpty ? nil : $0 }
        let text = arguments["Text"].flatMap { $0.isEmpty ? nil : $0 }
        guard header != nil || text != nil else { return }
        let duration = arguments["TimeoutMs"].flatMap(Int.init).flatMap { $0 > 0 ? Duration.milliseconds($0) : nil }
        message = Message(header: header, text: text, duration: duration ?? Self.defaultMessageDuration)
    }
}
