//
//  SearchView.swift
//  Venuu
//
//  Created by J J on 11/8/22.
//

import SwiftUI

    struct SearchView: View {
        @State private var artistSearch: String = ""
        @State private var title = ""
        @State private var artists: [SetListFM.Setlist] = []
        @State private var noResults: String = ""
       
        var body: some View {
            NavigationStack {
                VStack {
                    TextField("Artist Name", text: $artistSearch)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") {
                        noResults = ""
                        title = ""
                        artists = []
                        
                        //MARK: - API TASK
                        Task {
                            if let encodedArtist = artistSearch
                                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                                do {
                                    let setList: SetListFM.Setlist = try await APIService(urlString: Constants.baseURL + "setlists?artistName\(encodedArtist)&countryCode=US&p=1").getJSON()
                                    artists = setList.artist.name.sorted(by: {$0.sortName < $1.sortName})
                                    title = artistSearch
                                    artistSearch = ""
                                } catch  {
                                    noResults = "No Results Found"
                                }
                            }
                        }
                    } // End Button
                    .buttonStyle(.bordered)
                    Text(title).font(.title2)
                    if noResults.isEmpty {
                        List(artists, id: \.self.id) { artist in
                            VStack(alignment: .leading) {
                                Text(artist.artist.name).font(.title)
//                                Link(artist.url.absoluteString, destination: artist.url)
                            }
                        }
                        .listStyle(.plain)
                    } else {
                        Text(noResults).foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding()
                .onAppear {
                        UITextField.appearance().clearButtonMode = .whileEditing
                }
                .navigationTitle("Search Concerts")
            }
            
        }
    }


struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}

