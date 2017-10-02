import Foundation
import PromiseKit

let port = 4381
let headers = [
    "Origin": "https://open.spotify.com",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.148 Safari/537.36 Vivaldi/1.4.589.38"
]
let oauthUrl = URL(string: "http://open.spotify.com/token")!

enum SpotifyStatus {
    case idle
    case initialized(oAuthToken: String, csrfToken: String)
}

func randomLocalHostname() -> String {
    let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    return String(uuid.prefix(10)) + ".spotilocal.com"
}

func buildUrl(withPath path: String, queryItems: [URLQueryItem]? = nil) -> URL {
    var urlComponents = URLComponents()
    urlComponents.scheme = "http"
    urlComponents.host = randomLocalHostname()
    urlComponents.port = port
    urlComponents.path = path
    urlComponents.queryItems = queryItems

    return urlComponents.url!
}

enum SpotifyCommand {
    case status
    case pause
    case resume
    case csrfToken
    case custom(path: String)

    var path: String {
        switch self {
        case .status:
            return "/remote/status.json"
        case .pause, .resume:
            return "/remote/pause.json"
        case .csrfToken:
            return "/simplecsrf/token.json"
        case .custom(let path):
            return path
        }
    }

    var params: [URLQueryItem]? {
        switch self {
        case .pause:
            return [URLQueryItem(name: "pause", value: "true")]
        case .resume:
            return [URLQueryItem(name: "pause", value: "false")]
        default:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .csrfToken:
            return false
        default:
            return true
        }
    }
}

class SpotifyRepository {

    var session: URLSession

    private var status: SpotifyStatus = .idle

    init(session: URLSession) {
        self.session = session
    }

    func execute(command: SpotifyCommand) -> Promise<Data> {
        if command.requiresAuthentication {
            return self.checkStatus().then { status -> Promise<Data> in
                guard case let .initialized(oAuthToken, csrfToken) = status else {
                    throw SpotifyError.noData
                }

                let authQueryItems = [
                    URLQueryItem(name: "oauth", value: oAuthToken),
                    URLQueryItem(name: "csrf", value: csrfToken)
                ]

                let url = buildUrl(withPath: command.path,
                                   queryItems: (command.params ?? []) + authQueryItems
                )

                return self.execute(withUrl: url)
            }
        } else {
            let url = buildUrl(withPath: command.path, queryItems: command.params)
            return self.execute(withUrl: url)
        }
    }

    private func execute(withUrl url: URL) -> Promise<Data> {
        var urlRequest = URLRequest(url: url)
        headers.forEach { header, value in
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        return Promise { fulfill, reject in
            session.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    reject(error)
                    return
                }

                guard let data = data else {
                    reject(SpotifyError.noData)
                    return
                }

                fulfill(data)
            }.resume()
        }
    }

    private func checkStatus() -> Promise<SpotifyStatus> {
        switch self.status {
        case .idle:
            return when(fulfilled: [getOauthToken(), getCsrfToken()]).then { result -> SpotifyStatus in
                guard let oAuthToken = result.first, let csrfToken = result.last else {
                    throw SpotifyError.noData
                }
                return .initialized(oAuthToken: oAuthToken, csrfToken: csrfToken)
            }
        case .initialized:
            return Promise(value: self.status)
        }
    }

    private func getOauthToken() -> Promise<String> {
        return execute(withUrl: oauthUrl).then { data -> String in
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonDict = json as? [String: Any],
                      let oAuthToken = jsonDict["t"] as? String else {
                    throw SpotifyError.noData
                }
                return oAuthToken
            } catch {
                throw SpotifyError.serializationError(error)
            }
        }
    }

    private func getCsrfToken() -> Promise<String> {
        return execute(command: .csrfToken).then { data -> String in
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonDict = json as? [String: Any],
                      let csrfToken = jsonDict["token"] as? String else {
                    throw SpotifyError.noData
                }
                return csrfToken
            } catch {
                throw SpotifyError.serializationError(error)
            }
        }
    }
}

public enum SpotifyError: Error {
    case noData
    case serializationError(Error)
}

let session = URLSession(configuration: .default)
let repository = SpotifyRepository(session: session)

repository.execute(command: .pause)

dispatchMain()
