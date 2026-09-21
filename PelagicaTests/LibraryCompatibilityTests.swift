import Foundation
import JellyfinAPI
import XCTest
@testable import Pelagica

final class LibraryCompatibilityTests: XCTestCase {
    func testMixedAndUntypedViewsRemainBrowsable() throws {
        let data = Data(#"{"Items":[{"Id":"untyped","Type":"CollectionFolder"},{"Id":"null","Type":"CollectionFolder","CollectionType":null},{"Id":"mixed","Type":"CollectionFolder","CollectionType":"mixed"},{"Id":"movies","Type":"CollectionFolder","CollectionType":"movies"},{"Id":"series","Type":"CollectionFolder","CollectionType":"tvshows"},{"Id":"nested","Type":"Folder"},{"Id":"not-a-library","Type":"Movie"},{"Type":"CollectionFolder"}],"TotalRecordCount":8}"#.utf8)
        let response = try ItemResponseDecoder.decode(BaseItemDtoQueryResult.self, from: data, shape: .queryResult)
        let libraries = (response.items ?? []).filter(LibraryPolicy.isLibrary)
        XCTAssertEqual(libraries.compactMap(\.id), ["untyped", "null", "mixed", "movies", "series", "nested"])
        XCTAssertNil(LibraryPolicy.recentItemTypes(for: libraries[2].collectionType))
    }

    func testEverySDKCollectionKindIsAcceptedAsALibrary() throws {
        let views = CollectionType.allCases.map { type in
            BaseItemDto(collectionType: type, id: type.rawValue, type: .collectionFolder)
        }
        XCTAssertEqual(views.filter(LibraryPolicy.isLibrary).compactMap(\.id), CollectionType.allCases.map(\.rawValue))
    }

    func testNormalizationDoesNotRewriteMetadataOrDropNestedPrograms() throws {
        let data = Data(#"{"Id":"parent","CollectionType":"mixed","ProviderIds":{"CollectionType":"mixed"},"DateCreated":"2026-01-02T03:04:05.1234567Z","CurrentProgram":{"Id":"program","CollectionType":"mixed","Name":"Current programme"}}"#.utf8)
        let item = try ItemResponseDecoder.decode(BaseItemDto.self, from: data, shape: .item)
        XCTAssertEqual(item.providerIDs?["CollectionType"], "mixed")
        XCTAssertEqual(item.currentProgram?.name, "Current programme")
        XCTAssertEqual(item.currentProgram?.collectionType, .unknown)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(calendar.component(.year, from: try XCTUnwrap(item.dateCreated)), 2026)
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(item.dateCreated)), 2)
    }

    func testUnknownValuesAndMalformedMetadataStillFail() {
        for (json, key) in [
            (#"{"Id":"bad","CollectionType":"future-kind"}"#, "CollectionType"),
            (#"{"Id":"bad","CollectionType":"mixed","MediaType":"invalid"}"#, "MediaType")
        ] {
            XCTAssertThrowsError(try ItemResponseDecoder.decode(BaseItemDto.self, from: Data(json.utf8), shape: .item)) { error in
                guard case DecodingError.dataCorrupted(let context) = error else {
                    return XCTFail("Unexpected decoding error: \(error)")
                }
                XCTAssertEqual(context.codingPath.last?.stringValue, key)
            }
        }
    }

    func testArrayResponsesPreservePlaylistOccurrences() throws {
        let data = Data(#"[{"Id":"a","PlaylistItemId":"first","CollectionType":"mixed"},{"Id":"b","PlaylistItemId":"second"},{"Id":"a","PlaylistItemId":"third","CollectionType":"mixed"}]"#.utf8)
        let items = try ItemResponseDecoder.decode([BaseItemDto].self, from: data, shape: .list)
        XCTAssertEqual(items.compactMap(\.playlistItemID), ["first", "second", "third"])
        XCTAssertEqual(items.compactMap(\.id), ["a", "b", "a"])
    }

    func testFoldersCannotPlayAndSeriesKeepTheirOwnDetails() {
        let folder = BaseItemDto(id: "folder", isFolder: true, type: .folder)
        let series = BaseItemDto(id: "series", isFolder: true, type: .series)
        let book = BaseItemDto(id: "book", type: .book)
        let episode = BaseItemDto(id: "episode", type: .episode)
        XCTAssertTrue(LibraryPolicy.isContainer(folder))
        XCTAssertFalse(LibraryPolicy.canPlayVideo(folder))
        XCTAssertFalse(LibraryPolicy.isContainer(series))
        XCTAssertFalse(LibraryPolicy.canPlayVideo(series))
        XCTAssertFalse(LibraryPolicy.canPlayVideo(book))
        XCTAssertTrue(LibraryPolicy.canPlayVideo(episode))
    }
}
