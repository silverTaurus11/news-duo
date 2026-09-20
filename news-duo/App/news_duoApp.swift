//
//  news_duoApp.swift
//  news-duo
//
//  Created by Gayuh Nurul Huda on 20/09/26.
//

import SwiftUI

@main
struct news_duoApp: App {
    @State private var container = AppContainer(configuration: AppConfig.newsAPI)

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
