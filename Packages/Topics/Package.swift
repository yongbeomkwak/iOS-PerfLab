// swift-tools-version: 6.0
import PackageDescription

/// 주제 모듈 목록. `scripts/perflab new`가 아래 마커 위에 자동으로 추가한다.
let topics: [TopicModule] = [
    // @perflab:topics
]

struct TopicModule {
    /// 모듈 이름. 예) `Topic01ImageFeedScroll`
    let name: String
    /// 패키지 기준 경로. 예) `Rendering/01-image-feed-scroll`
    let path: String
}

let shared: Target.Dependency = .product(name: "Shared", package: "Shared")

let package = Package(
    name: "Topics",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TopicCatalog", targets: ["TopicCatalog"]),
    ],
    dependencies: [
        .package(path: "../Shared"),
    ],
    targets: [
        .target(
            name: "TopicCatalog",
            dependencies: [shared] + topics.map { .target(name: $0.name) },
            path: "Catalog"
        ),
    ] + topics.flatMap { topic -> [Target] in
        [
            .target(
                name: topic.name,
                dependencies: [shared],
                path: topic.path,
                exclude: ["Tests", "docs", "results"],
                resources: [.copy("topic.json")]
            ),
            .testTarget(
                name: "\(topic.name)Tests",
                dependencies: [.target(name: topic.name), shared],
                path: "\(topic.path)/Tests"
            ),
        ]
    }
)
