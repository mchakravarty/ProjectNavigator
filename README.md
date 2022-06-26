# ProjectNavigator

*NB:* This package requires Xcode 14 (beta).

This package offers support for SwiftUI project navigation for macOS and iOS. At the core is a file tree navigator that can be used inside a `NavigationView`. The package consists of two libraries: (1) `Files` and (2) `ProjectNavigator`. 

## `Files`

The `Files` library serves as the model representing a file tree that can be marshalled from and to `FileWrapper`s. Individual files and folders are also assigned `UUID`s with support to persist the assignment. This is useful to support persistent view and other configuration.

## `FileNavigator`

The `FileNavigator` view provides navigation to associated files inside an enclosing `NavigationView`. Both navigation labels as well as the navigation destination view are freely configurable.

## NavigatorDemo

The folder [`NavigatorDemo`](NavigatorDemo) contains a simple example application that facilitates the navigation and editing of a bundle of text files.
