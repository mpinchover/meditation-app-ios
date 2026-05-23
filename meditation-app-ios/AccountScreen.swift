//
//  AccountScreen.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 5/23/26.
//

import SwiftUI

struct AccountScreen: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appThemedScreen()
            .navigationTextBackButton()
    }
}

#Preview {
    NavigationStack {
        AccountScreen()
    }
}
