extension AppAlert {
    /// A video tapped offline. The player has nothing to show without a connection, so the grid stays and says why.
    static var videoNeedsConnection: AppAlert {
        AppAlert(title: "You're offline", message: "Check your internet connection to play this video.")
    }

    /// A video the viewer could not load, most often because the connection dropped.
    static var videoFailedToLoad: AppAlert {
        AppAlert(title: "Can't play this video", message: "Check your internet connection and try again.")
    }
}
