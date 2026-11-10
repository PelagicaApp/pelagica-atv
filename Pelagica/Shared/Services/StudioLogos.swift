//
//  StudioLogos.swift
//  Pelagica
//

import Foundation

/// Resolves studio names to TMDB logo paths using the Pelagica studios index, cached on disk and refreshed weekly.
actor StudioLogos {
    static let shared = StudioLogos()

    private static let indexURL = URL(string: "https://studios.pelagica.app/companies_minimal.json")!
    private static let tmdbImageBaseURL = "https://image.tmdb.org/t/p/"
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    private struct Company: Decodable {
        let logo_path: String
    }

    private var logos: [String: String]?
    private var loadTask: Task<[String: String], Never>?
    private var isRefreshing = false

    private var cacheFileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("studio-logos.json")
    }

    func logoPath(for studioName: String) async -> String? {
        await loadLogos()[studioName]
    }

    nonisolated static func logoURL(for logoPath: String, size: String = "w300") -> URL? {
        URL(string: tmdbImageBaseURL + size + "_filter(duotone,ffffff,bababa)" + logoPath)
    }

    private func loadLogos() async -> [String: String] {
        if let logos { return logos }
        if let loadTask { return await loadTask.value }

        let task = Task { await loadFromDiskOrNetwork() }
        loadTask = task
        let result = await task.value
        logos = result
        loadTask = nil
        return result
    }

    private func loadFromDiskOrNetwork() async -> [String: String] {
        if let data = try? Data(contentsOf: cacheFileURL), let cached = Self.decode(data) {
            let modified = (try? cacheFileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if Date().timeIntervalSince(modified ?? .distantPast) >= Self.maxAge {
                Task { await refreshInBackground() }
            }
            return cached
        }
        return await fetchAndStore() ?? [:]
    }

    private func refreshInBackground() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = await fetchAndStore() {
            logos = fresh
        }
    }

    private func fetchAndStore() async -> [String: String]? {
        guard
            let (data, response) = try? await URLSession.shared.data(from: Self.indexURL),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let fresh = Self.decode(data)
        else { return nil }
        try? data.write(to: cacheFileURL, options: .atomic)
        return fresh
    }

    private static func decode(_ data: Data) -> [String: String]? {
        guard let companies = try? JSONDecoder().decode([String: Company].self, from: data) else { return nil }
        return companies.mapValues(\.logo_path)
    }
}
