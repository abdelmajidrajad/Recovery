import SwiftUI
import ComposableArchitecture
import Combine
import Library


struct AppState: Equatable {
    var activity: Activity?
    var isRequestInFlight: Bool
    var shareItem: ShareItem?
    init(
        activity: Activity? = nil,
        isRequestInFlight: Bool = false,
        shareItem: ShareItem? = nil
    ) {
        self.shareItem = shareItem
        self.activity = activity
        self.isRequestInFlight = isRequestInFlight
    }
}

enum AppAction: Equatable {
    case settingButtonTapped
    case shuffleButtonTapped
    case shareButtonTapped
    case openLinkButtonTapped
    case shareSheetDismissed
    case share(UIImage)
    case response(Result<Activity, ApiError>)
}


enum ApiError: LocalizedError, Equatable {
    case custom(String)
}

struct NetworkClient {
    let activity: () -> Effect<Activity, ApiError>
}

struct AppEnvironment {
    let networkClient: NetworkClient
    let shareClient: ShareClient
    let mainQueue: AnySchedulerOf<DispatchQueue>
}


extension AppEnvironment {
    static var mock: AppEnvironment {
        AppEnvironment(
            networkClient: NetworkClient(
                activity: {
                    Just(
                        Int.random(in: 0...99) % 2 == 0
                        ? Activity.drawColor
                            : .dailyJournal
                    )
                        .setFailureType(to: ApiError.self)
                        .delay(
                            for: 2.0,
                            scheduler: DispatchQueue.main.eraseToAnyScheduler())
                        .eraseToEffect()
                }
            ),
            shareClient: .mock,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        )
    }
}

extension AppEnvironment {
    static var live: AppEnvironment {
        AppEnvironment(
            networkClient: NetworkClient(
                activity: {
                    URLSession.shared.dataTaskPublisher(for: URL(string: "https://www.boredapi.com/api/activity")!)
                    .map { data, _ in data }
                    .decode(type: Activity.self, decoder: JSONDecoder())
                    .mapError { error in .custom(error.localizedDescription) }
                    .eraseToEffect()
                }
            ),
            shareClient: .live,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        )
    }
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
    state, action, environment in
    switch action {
    case .settingButtonTapped:
        return .none
    case .shuffleButtonTapped:
        state.isRequestInFlight = true
        state.activity = nil
        return environment.networkClient
            .activity()
            .receive(on: environment.mainQueue)
            .catchToEffect()
            .map(AppAction.response)
    case .shareButtonTapped:
        return environment.shareClient.snapShot(
            VStack(spacing: .py_grid(2)) {
                Text("Feel Boring ?")
                    .foregroundColor(Color(.label))
                    .font(.headline)
                Text("Let's make this activity")
                    .foregroundColor(Color(.secondaryLabel))
                    .font(.footnote)
                ActivityView(viewStore: .constant(state.view))
            }.frame(width: .py_grid(80), height: .py_grid(80))
            .padding(.py_grid(1))
            .anyView()
        )
        .map(AppAction.share)
        .eraseToEffect()
    case let .share(image):
        state.shareItem = ShareItem(
            image: image,
            appURL: URL(string: "https://apps.apple.com/us/app/id1525697865")!
        )
        return .none
            /*share([image, URL(string: "https://apps.apple.com/us/app/id1525697865")!])
            .receive(on: DispatchQueue.main.eraseToAnyScheduler())
            .eraseToEffect()
            .fireAndForget() */
    case .openLinkButtonTapped:
        return openURL(state.activity!.link)
            .fireAndForget()
    case let .response(.success(activity)):
        state.isRequestInFlight = false
        state.activity = activity
        return .none
    case let .response(.failure(error)):
        state.isRequestInFlight = false
        return .none
    case .shareSheetDismissed:
        state.shareItem = nil
        return .none
    }
}

func openURL(_ link: String) -> Effect<Never, Never> {
    .fireAndForget {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(
            url,
            options: [:],
            completionHandler: nil
        )
    }
}

import CoreGraphics
extension CGFloat {
    public static func py_grid(_ value: Int) -> CGFloat {
        CGFloat(4 * value)
    }
}


struct Activity: Codable, Equatable {
    private let activity: String
    let type: String
    let participants: Int
    let price: Float
    let link: String
    let key: String
    let accessibility: Float
    
    var title: String {
        activity
    }
}


struct ShareItem: Identifiable, Equatable {
    var id: UUID { UUID() }
    let image: UIImage
    let appURL: URL
}

let activities: (ShareItem) -> [Any] = {
    [$0.image, $0.appURL]
}

extension Activity {
    static var drawColor: Self {
        .init(
            activity: "Make a scrapbook with pictures of your favorite memories",
            type: "relaxation",
            participants: 1,
            price: 0.94,
            link: "https://en.wikipedia.org/wiki/Mandala",
            key: "4614092",
            accessibility: 0.1
        )
    }
    
        
    static var dailyJournal: Self {
        .init(
            activity: "Start a daily journal",
            type: "relaxation",
            participants: 1,
            price: 0,
            link: "",
            key: "8779876",
            accessibility: 0
        )
    }
    
}

extension Activity {
    var kind: String {
        type + " " + emoji(type)
    }
}


extension AppState {
    var view: ContentView.ViewState {
        .init(
            title: activity?.title ?? "",
            type: activity?.kind ?? "",
            status: isRequestInFlight ? "happy": "bored",
            hasLink: activity?.link != nil && activity?.link != "",
            hasParticipants: activity?.participants != .zero,
            participants: "\(activity?.participants ?? .zero)" ,
            participantsIcon:
                activity?.participants == .zero
                ? ""
                : activity?.participants == 1
                ? "person.fill"
                : activity?.participants == 2
                ? "person.2.fill"
                : "person.3.fill"
            ,
            price:
                activity?.price != nil
                ? numberFormatter().string(from: NSNumber(value: activity!.price)) ?? ""
                : ""
            ,
            hasPrice: activity?.price != .zero,
            isExist: activity != nil,
            shareItem: shareItem
        )
    }
}

let numberFormatter: () -> NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
}

struct ContentView: View {
    
    struct ViewState: Equatable {
        var title: String
        var type: String
        var status: String
        var hasLink: Bool
        var hasParticipants: Bool
        var participants: String
        var participantsIcon: String
        var price: String
        var hasPrice: Bool
        var isExist: Bool
        var shareItem: ShareItem?
    }
        
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store.scope(state: \.view)) { viewStore in
            
            VStack {
                                               
                Spacer()
                
                if viewStore.isExist {
                    ActivityView(viewStore: .constant(viewStore.state))
                } else {
                    Image(viewStore.status)
                        .resizable()
                        .frame(width: 50, height: 50)
                }
                
                //Spacer()
                VStack(spacing: 32) {
                    HStack {
                        if viewStore.hasLink {
                            Button(action: {
                                viewStore.send(.openLinkButtonTapped)
                            }) {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                                Text("Open ")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                            }//.frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 16.0,
                                    style: .continuous
                                ).fill(Color.orange.opacity(0.1))
                            )
                        }
                        if viewStore.isExist {
                            Button(action: {
                                withAnimation {
                                    viewStore.send(.shareButtonTapped)
                                }
                            }, label: {
                                HStack {
                                    Text("Share")
                                    Image(systemName: "square.and.arrow.up.fill")
                                }
                                .font(Font.headline.bold())
                                .padding()
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16.0,
                                        style: .continuous
                                    ).fill(Color.blue.opacity(0.1))
                                )
                            })
                            .sheet(item: viewStore.binding(
                                    get: \.shareItem,
                                    send: AppAction.shareSheetDismissed)) { item in
                                ShareSheet(activityItems: activities(item))
                            }
                        }
                    }
                    
                    HStack {
                        Button(action: {
                            withAnimation {
                                viewStore.send(.shuffleButtonTapped)
                            }
                        }, label: {
                            HStack {
                                Text("Shuffle")
                                Image(systemName: "shuffle")
                            }
                            .font(Font.headline.bold())
                            .padding()
                            .padding(.horizontal)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 16.0,
                                    style: .continuous
                                ).fill(Color.blue.opacity(0.1))
                            ).transition(.identity)
                        })
                    }
                }
            }.navigationBarTitle("Feel Bored ?")
            .padding()
            
          
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentView(
                store: Store(
                    initialState: AppState(),
                    reducer: appReducer,
                    environment: AppEnvironment(
                        networkClient: NetworkClient(
                            activity: {
                                Just(
                                    Int.random(in: 1...100) % 2 == 0
                                    ? Activity.drawColor
                                        : .dailyJournal
                                    
                                    
                                )
                                    .setFailureType(to: ApiError.self)
                                    .delay(
                                        for: 2.0,
                                        scheduler: DispatchQueue.main.eraseToAnyScheduler())
                                    .eraseToEffect()
                            }
                        ),
                        shareClient: .mock,
                        mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                    ))
            )
        }
//        ContentView(
//            store: Store(
//                initialState: AppState(activity: .drawColor),
//                reducer: .empty,
//                environment: ()
//            )
//        )
//            .preferredColorScheme(.dark)
    }
}

enum ActivityType: String {
    case social = "👨‍👩‍👦"
    case relaxation = "🛀"
    case education = "📚"
    case diy = "🪔"
    case busywork = "👷‍♀️"
    case charity = "🎗"
    case recreational = "🧑‍🎨"
    case cooking = "🥘"
    case music = "🎶"
}

func emoji(_ activity: String) -> String {
    switch activity {
    case "social": return "👨‍👩‍👦"
    case "relaxation": return "🛀"
    case "education": return "📚"
    case "diy": return "🪔"
    case "busywork": return "👷‍♀️"
    case "charity": return "🎗"
    case "recreational": return "🧑‍🎨"
    case "cooking": return "🥘"
    case "music": return "🎶"
    default: return ""
    }
}


struct ActivityView: View {
    @Binding var viewStore: ContentView.ViewState
    var body: some View {
        VStack {
            
            VStack {
                Text(viewStore.type.uppercased())
                    .foregroundColor(Color.orange)
                    .font(.subheadline)
                    .padding(8)
                    .background(
                        Capsule()
                            .stroke(Color.yellow.opacity(0.1))
                    )
                Text(viewStore.title.uppercased())
                    .multilineTextAlignment(.center)
                    .font(Font.headline.bold())
                    .padding()
                    .foregroundColor(Color(.orange))
                    .background(
                        RoundedRectangle(
                            cornerRadius: 25.0,
                            style: .continuous
                        )
                        .fill(
                            Color.orange.opacity(0.1)
                        )
                    )
            }
            
            
            HStack {
                
                HStack {
                    Image(systemName: viewStore.participantsIcon)
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text(viewStore.participants)
                        .foregroundColor(Color.orange)
                        .font(.headline)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                        )
                }.padding(8)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16.0,
                        style: .continuous
                    ).stroke(Color.yellow.opacity(0.1))
                )
                
                //if viewStore.hasPrice {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.headline)
                        .foregroundColor(Color.orange)
                    Text(viewStore.price)
                        .foregroundColor(.orange)
                        .font(.headline)
                        .padding(8)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                        )
                }.padding(8)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16.0,
                        style: .continuous
                    ).stroke(Color.yellow.opacity(0.1))
                ).transition(.opacity)
            }
            
        }.padding()
        .background(
            RoundedRectangle(
                cornerRadius: 16.0,
                style: .continuous
            ).fill(Color(.systemBackground))
            .shadow(color: Color.orange.opacity(0.3), radius: 1)
        ).padding()
        .transition(AnyTransition
                        .slide.animation(.linear)
        ).animation(.linear)
    }
}

//Share Client
import Combine
struct ShareClient {
    let snapShot: (AnyView) -> AnyPublisher<UIImage, Never>
}

extension ShareClient {
    static var live: Self {
        Self(
            snapShot: { view in
                Future<UIImage, Never> { promise in
                    view
                    .snapShot(
                        origin: .zero,
                        size: CGSize(width: .py_grid(100), height: .py_grid(100))) { image in
                        promise(.success(image))
                    }
                }.eraseToAnyPublisher()
            }
        )
    }
}

extension ShareClient {
    static var mock: Self {
        .init(
            snapShot: { _ in Just(UIImage(named: "progressIcon")!)
                .eraseToAnyPublisher() }
        )
    }
}
