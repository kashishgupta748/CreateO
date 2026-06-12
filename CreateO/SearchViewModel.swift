import Foundation
import Observation

@Observable
class SearchViewModel {
    
    var searchText: String = ""
    
    var designResults: [Design] = []
    var albumResults: [Album] = []
    
    func search(_ store: DataStore) {
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            designResults = []
            albumResults = []
            return
        }
        
        designResults = store.designs.filter {
            $0.designName.localizedCaseInsensitiveContains(query)
        }
        
        albumResults = store.albums.filter {
            $0.albumName.localizedCaseInsensitiveContains(query)
        }
    } 
}
