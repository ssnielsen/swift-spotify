//
//  main.swift
//  swift-spotify
//
//  Created by Soren Sonderby Nielsen on 02/10/2017.
//

import Foundation

private let map: [String: SpotifyCommand] = [
    "resume": .resume,
    "pause": .pause
]

extension Array {
    subscript(safeIndex index: Int) -> Element? {
        get {
            if !(0..<count).contains(index) {
                return nil
            }

            return self[index]
        }
    }
}

guard let commandString = CommandLine.arguments[safeIndex: 1] else {
    print("Please provide an argument")
    exit(EXIT_SUCCESS)
}

guard let command = map[commandString] else {
    print("Please provide a valid argument")
    print(map)
    exit(EXIT_SUCCESS)
}

private func execute(command: SpotifyCommand) {
    let session = URLSession(configuration: .default)
    let repository = SpotifyRepository(session: session)
    repository.execute(command: command)
        .then { data -> Void in
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
            exit(EXIT_SUCCESS)
        }.catch { error in
            print(error)
            exit(EXIT_FAILURE)
        }

    dispatchMain()
}

execute(command: command)
