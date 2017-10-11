//
//  main.swift
//  swift-spotify
//
//  Created by Soren Sonderby Nielsen on 02/10/2017.
//

import Foundation
import Commander
import SwiftyJSON


private func prettyPrint(with json: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
        return "nil"
    }

    let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
    return (string as String?) ?? "nil"
}

private func execute(command: SpotifyCommand) {
    let session = URLSession(configuration: .default)
    let repository = SpotifyRepository(session: session)
    repository.execute(command: command)
        .then { data -> Void in
            if let json = command.extractOutput(fromData: data),
               let prettyJson = json.rawString(.utf8, options: [.prettyPrinted]) {
                print(prettyJson)
            }
            exit(EXIT_SUCCESS)
        }
        .catch { error in
            print(error)
            exit(EXIT_FAILURE)
        }

    dispatchMain()
}

let main = Group {
    $0.command("resume") {
        execute(command: .resume)
    }

    $0.command("pause") {
        execute(command: .pause)
    }

    $0.command("version") {
        execute(command: .version)
    }

    $0.command("status") {
        execute(command: .status)
    }

    $0.command("playing") {
        execute(command: .songInfo)
    }
}

main.run()
