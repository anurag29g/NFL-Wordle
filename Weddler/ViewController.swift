//
//  ViewController.swift
//  Weddler
//
//  Created by Anurag Ghadge on 6/14/23.
//


import UIKit

struct Player: Decodable {
    let position: String
    let name: String
}

class ViewController: UIViewController {
    @IBOutlet var field: UITextField!
    @IBOutlet var button: UIButton!
    @IBOutlet var playerNameLabel: UILabel!
    @IBOutlet var hintButton: UIButton!
    @IBOutlet var quarterbacksButton: UIButton!
    @IBOutlet var wideReceiversButton: UIButton!
    @IBOutlet var runningBacksButton: UIButton!

    var players: [Player] = []
    var filteredPlayers: [Player] = []
    var depthCharts: [[String: Any]] = []
    var currentPlayerIndex = 0
    var attempts = 0
    var hintButtonClickedCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        field.returnKeyType = .done
        field.becomeFirstResponder()
        field.delegate = self
        field.autocorrectionType = .no
        fetchPlayers { [weak self] result in
            switch result {
            case .success(let players):
                self?.players = players
                self?.resetGame()
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    @IBAction func buttonTapped() {
        field.resignFirstResponder()
    }

    @IBAction func hintButtonTapped() {
        guard currentPlayerIndex < filteredPlayers.count else {
            print("Invalid player index.")
            return
        }

        let currentPlayer = filteredPlayers[currentPlayerIndex]

        if hintButtonClickedCount == 0 {
            
            let positionType = currentPlayer.position.lowercased().contains("offense") ? "Offensive" : "Defensive"
            showAlert(message: "The player is an \(positionType) player.")
        } else if hintButtonClickedCount == 1 {
            
            showAlert(message: "The player's position is \(currentPlayer.position).")
        } else if hintButtonClickedCount == 2 {
            
            let playerDepthOrder = getPlayerDepthOrder(playerName: currentPlayer.name)

            if let depthOrder = playerDepthOrder {
                showAlert(message: "The player's depth order is \(depthOrder).")
            } else {
                showAlert(message: "Depth order information is not available for this player.")
            }
        }

        hintButtonClickedCount += 1
    }

    @IBAction func quarterbacksButtonTapped() {
        filterPlayersByPosition(position: "Quarterback")
        resetGame()
    }

    @IBAction func wideReceiversButtonTapped() {
        filterPlayersByPosition(position: "Wide Receiver")
        resetGame()
    }

    @IBAction func runningBacksButtonTapped() {
        filterPlayersByPosition(position: "Running Back")
        resetGame()
    }

    //check this later
    func fetchPlayers(completion: @escaping (Result<[Player], Error>) -> Void) {
        let apiKey = "47ed59b2b7174cd0a09a223ba4a563eb"
        let urlString = "https://api.sportsdata.io/v3/nfl/scores/json/DepthCharts?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "Invalid URL", code: 0, userInfo: nil)
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "Data is missing", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                self?.depthCharts = json ?? []

                var players: [Player] = []

                for team in json ?? [] {
                    if let offense = team["Offense"] as? [[String: Any]] {
                        for playerData in offense {
                            if let position = playerData["Position"] as? String, let name = playerData["Name"] as? String {
                                let player = Player(position: position, name: name)
                                players.append(player)
                            }
                        }
                    }

                    if let defense = team["Defense"] as? [[String: Any]] {
                        for playerData in defense {
                            if let position = playerData["Position"] as? String, let name = playerData["Name"] as? String {
                                let player = Player(position: position, name: name)
                                players.append(player)
                            }
                        }
                    }
                }

                completion(.success(players))
            } catch let decodingError {
                let errorDescription = decodingError.localizedDescription
                let error = NSError(domain: "Decoding Error", code: 0, userInfo: [NSLocalizedDescriptionKey: errorDescription])
                completion(.failure(error))
            }
        }.resume()
    }

    func filterPlayersByPosition(position: String) {
        if position == "Quarterback" {
            filteredPlayers = players.filter { $0.position.lowercased() == "qb" }
        } else if position == "Wide Receiver" {
            filteredPlayers = players.filter { $0.position.lowercased().contains("wr") }
        } else if position == "Running Back" {
            filteredPlayers = players.filter { $0.position.lowercased() == "rb" }
        } else {
            filteredPlayers = players
        }
    }

    func startNewGame() {
        hintButtonClickedCount = 0

        DispatchQueue.main.async {
            if self.filteredPlayers.isEmpty {
                
                self.playerNameLabel.text = "No players available in this category"
                
            } else {
                self.currentPlayerIndex = Int.random(in: 0..<self.filteredPlayers.count)
                let currentPlayer = self.filteredPlayers[self.currentPlayerIndex]
                self.playerNameLabel.text = currentPlayer.name
                self.attempts = 0
            }
        }
    }

    func resetGame() {
        DispatchQueue.main.async {
            self.attempts = 0
            if self.filteredPlayers.isEmpty {
                self.players.shuffle()
                self.filteredPlayers = self.players
            }
            self.currentPlayerIndex = Int.random(in: 0..<self.filteredPlayers.count)
            let currentPlayer = self.filteredPlayers[self.currentPlayerIndex]
            self.playerNameLabel.text = currentPlayer.name
        }
    }


    func checkGuess(guess: String) {
        attempts += 1

        guard currentPlayerIndex < filteredPlayers.count else {
            print("Invalid player index.")
            return
        }

        let currentPlayer = filteredPlayers[currentPlayerIndex]
        if guess.lowercased() == currentPlayer.name.lowercased() {
            let message = "Correct! The player's name is \(currentPlayer.name). Position: \(currentPlayer.position)"
            showAlert(message: message)
            startNewGame()
        } else if attempts > 7 {
            let message = "Game over! The player's name is \(currentPlayer.name). Position: \(currentPlayer.position)"
            showAlert(message: message)
            resetGame()
        } else {
            showAlert(message: "Incorrect. Try again!")
        }
    }


    func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func getPlayerDepthOrder(playerName: String) -> Int? {
        for team in depthCharts {
            if let offense = team["Offense"] as? [[String: Any]] {   //make sure this works
                for (index, playerData) in offense.enumerated() {
                    if let name = playerData["Name"] as? String, name.lowercased() == playerName.lowercased() {
                        return index + 1
                    }
                }
            }

            if let defense = team["Defense"] as? [[String: Any]] {
                for (index, playerData) in defense.enumerated() {
                    if let name = playerData["Name"] as? String, name.lowercased() == playerName.lowercased() {
                        return index + 1
                    }
                }
            }
        }

        return nil
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let guess = textField.text {
            checkGuess(guess: guess)
        }
        textField.text = ""
        textField.resignFirstResponder()
        return true
    }
}

