import Shared
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ForEach(TopicCategory.allCases) { category in
                NavigationStack {
                    TopicListView(category: category)
                }
                .tabItem { Label(category.title, systemImage: category.symbolName) }
                .tag(category)
            }
        }
    }
}
