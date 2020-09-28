//
//  PatrolBoatView.swift
//
//  Created on 3/20/20.
//  Copyright © 2020 WildAid. All rights reserved.
//

import SwiftUI

struct PatrolBoatView: View {

    @EnvironmentObject var settings: Settings

    @ObservedObject var user = UserViewModel()
    @ObservedObject var onDuty = DutyState.shared

    @State private var location = LocationViewModel(LocationHelper.currentLocation)
    @State private var isActiveRootFromPreboardingView  = false
    @State private var isActiveRootFromSearchView = false
    @State private var showingProfilePage = false
    @State private var resetLocation = {}
    @State private var showingDrafts = false

    @State private var showingAlertItem: AlertItem?
    @State private var profilePicture: PhotoViewModel?
    @State private var draftBoardingsCount = 0

    let photoQueryManager = PhotoQueryManager.shared

    private enum Dimensions {
        static let bottomPadding: CGFloat = 75
        static let coordPadding: CGFloat = 58.0
        static let coordTopPadding: CGFloat = 14.0
        static let allCoordPadding: CGFloat = 48.0
        static let trailingPadding: CGFloat = 16.0
        static let trailingCoordPadding: CGFloat = 12.0
    }

    var body: some View {
        VStack {
            HStack {
                SearchBarButton(title: "Find records", action: showFindRecords)
                    .padding(.vertical, Dimensions.coordTopPadding)

                PatrolBoatUserView(photo: profilePicture,
                                   onSea: $onDuty.onDuty,
                                   action: { self.showingProfilePage.toggle() })
                    .padding(.trailing, Dimensions.trailingPadding)

                NavigationLink(destination: ProfilePageView(user: user,
                                                            dutyState: onDuty,
                                                            profilePicture: profilePicture),
                               isActive: $showingProfilePage) {
                                EmptyView()
                }
            }

            ZStack(alignment: .bottom) {
                MapComponentView(location: self.$location,
                    reset: self.$resetLocation,
                    isLocationViewNeeded: false)
                VStack {
                    HStack {
                        CoordsBoxView(location: location)
                            .padding(.trailing, Dimensions.trailingCoordPadding)
                            .padding(.leading, Dimensions.coordPadding)

                        LocationButton(action: resetLocation)
                            .padding(.trailing, Dimensions.coordTopPadding)
                    }
                        .padding(.top, Dimensions.coordTopPadding)
                    Spacer()
                    BottomPatrolView(draftBoardingsCount: $draftBoardingsCount,
                                     findAction: showFindRecords,
                                     boardVesselAction: showBoardVessel,
                                     draftBoardingsAction: showDraftRecords)

                    NavigationLink(
                        destination: PreboardingView(viewType: .preboarding,
                                                     onDuty: onDuty,
                                                     rootIsActive: $isActiveRootFromPreboardingView),
                        isActive: self.$isActiveRootFromPreboardingView) {
                            EmptyView()
                    }
                        .isDetailLink(false)

                    NavigationLink(
                        destination: PreboardingView(viewType: .searchRecords,
                                                     onDuty: onDuty,
                                                     rootIsActive: $isActiveRootFromSearchView),
                        isActive: $isActiveRootFromSearchView) {
                            EmptyView()
                    }
                        .isDetailLink(false)

                    NavigationLink(
                        destination: DraftBoardingsView(),
                        isActive: $showingDrafts) {
                            EmptyView()
                    }
                }
            }
                .edgesIgnoringSafeArea(.all)
                .navigationBarTitle(Text(""), displayMode: .inline)
                .navigationBarBackButtonHidden(true)
                .navigationBarHidden(true)
        }
            .showingAlert(alertItem: $showingAlertItem)
            .onAppear(perform: onAppear)
    }

    private func showGoOnDutyAlert() {
        showingAlertItem = AlertItem(title: "You're currently on land",
            message: "Change status to \"At Sea\"?",
            primaryButton: .default(Text("Yes"), action: goOnDutyAlertClicked),
            secondaryButton: .cancel())
    }

    /// Actions

    private func onAppear() {
        guard let user = settings.realmUser else {
            print("realmUser not set")
            return
        }
        self.user.email = user.emailAddress
        self.user.name.first = user.firstName
        self.user.name.last = user.lastName
        onDuty.user = self.user

        // set draft boardings count
        let predicate = NSPredicate(format: "draft == true && reportingOfficer.email == %@", user.emailAddress)
        let realmReports = user
            .agencyRealm()?
            .objects(Report.self)
            .filter(predicate)

        if let realmReports = realmReports {
            draftBoardingsCount = realmReports.count
        }

        profilePicture = getPicture(documentId: user.profilePictureDocumentId)
        location = LocationViewModel(LocationHelper.currentLocation)
    }

    private func goOnDutyAlertClicked() {
        self.onDuty.onDuty = true
        self.isActiveRootFromPreboardingView.toggle()
    }

    /// Logic

    private func getPicture(documentId: String?) -> PhotoViewModel? {
        guard let documentId = documentId else { return nil }
        let photos = photoQueryManager.photoViewModels(imagesId: [documentId])
        return photos.first
    }

    private func showFindRecords() {
        isActiveRootFromSearchView.toggle()
    }

    private func showBoardVessel() {
        if onDuty.onDuty {
            isActiveRootFromPreboardingView.toggle()
        } else {
            showGoOnDutyAlert()
        }
    }

    private func showDraftRecords() {
        showingDrafts.toggle()
    }
}

struct PatrolBoatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PatrolBoatView()
                .environmentObject(Settings.shared)
        }
    }
}
