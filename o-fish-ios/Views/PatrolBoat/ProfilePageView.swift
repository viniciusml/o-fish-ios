//
//  ProfilePageView.swift
//  
//  Created on 9/9/20.
//  Copyright © 2020 WildAid. All rights reserved.
//

import SwiftUI

struct ProfilePageView: View {
    @ObservedObject var user: UserViewModel
    @ObservedObject var dutyState: DutyState
    @State var profilePicture: PhotoViewModel?

    @Environment(\.presentationMode) var presentationMode

    @State private var dutyReports = [ReportViewModel]()
    @State private var startDuty = DutyChangeViewModel()
    @State private var plannedOffDutyTime = Date()
    @State private var showingPatrolSummaryView = false
    @State private var showingAlertItem: AlertItem?
    let settings = Settings.shared
    let photoQueryManager = PhotoQueryManager.shared

    private enum Dimensions {
        static let spacing: CGFloat = 32.0
        static let stackSpacing: CGFloat = 14.0
        static let leadingPadding: CGFloat = 20.0
        static let padding: CGFloat = 16.0
        static let lineWidth: CGFloat = 1.0
        static let radius: CGFloat = 50.0
    }

    var body: some View {
        VStack(alignment: .center, spacing: Dimensions.spacing) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: .zero) {
                    HStack(spacing: Dimensions.stackSpacing) {
                        PatrolBoatUserView(photo: profilePicture,
                                           onSea: $dutyState.onDuty,
                                           size: .large,
                                           action: edit)
                        VStack(alignment: .leading, spacing: .zero) {
                            Text(user.name.fullName)
                            Text(user.email)
                                .foregroundColor(.gray)
                        }
                        .font(.body)
                    }
                    Button(action: edit) {
                        Text("Edit")
                            .foregroundColor(.main)
                            .font(.caption1)
                            .padding(.leading, Dimensions.leadingPadding)
                    }
                }
                .padding(.all, Dimensions.padding)
                Divider()
                    .frame(height: Dimensions.lineWidth)

                Toggle(isOn: dutyBinding) {
                    Text(dutyState.onDuty ? "At Sea" :"Not At Sea")
                        .font(.callout)
                }
                .padding(.all, Dimensions.padding)

                Divider()
                    .frame(height: Dimensions.lineWidth)
            }
            .background(Color.white)
            VStack {
                Button(action: showLogoutAlert) {
                    Spacer()
                    Text("Log Out")
                        .font(.body)
                    Spacer()
                }
                .padding(.vertical, Dimensions.stackSpacing)
                .background(Color.white)
                .cornerRadius(Dimensions.radius)
                .overlay(
                    RoundedRectangle(cornerRadius: .infinity)
                        .stroke(Color.main, lineWidth: Dimensions.lineWidth)
                )
            }
            .padding(.horizontal, Dimensions.padding)
            Spacer()

            NavigationLink(destination:
                PatrolSummaryView(dutyReports: dutyReports,
                                  startDuty: startDuty,
                                  onDuty: dutyState,
                                  plannedOffDutyTime: plannedOffDutyTime,
                                  rootIsActive: .constant(false)),
                           isActive: $showingPatrolSummaryView) {
                            EmptyView()
            }
            .isDetailLink(false)
        }
        .background(Color.lightGrayButton)
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }) {
            Text("Close")
        })
            .showingAlert(alertItem: $showingAlertItem)
    }

    private var dutyBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.dutyState.onDuty },
            set: {
                if !$0 {
                    self.showOffDutyConfirmation()
                } else {
                    self.dutyState.onDuty = $0
                }
        })
    }

    private func edit() {
        showPhotoPickerTypeModal()
    }

    private func showLogoutAlert() {
        showingAlertItem = AlertItem(title: "Log Out?",
                                     message: "All draft boardings will be deleted!",
                                     primaryButton: .destructive(Text("Log Out"), action: logoutAlertClicked),
                                     secondaryButton: .cancel())
    }

    private func logoutAlertClicked() {
        guard let user = settings.realmUser else {
            print("Attempting to logout when no user logged in")
            return
        }

        user.logOut { _ in
            DispatchQueue.main.async {
                self.settings.realmUser = nil
            }
            NotificationManager.shared.removeAllNotification()
        }
    }

    private func showPhotoPickerTypeModal() {
        // TODO: for some reason this works only from action and not from viewModifier
        // TODO: review when viewModifier actions will be available
        guard settings.realmUser != nil else {
            print("realmUser not set")
            return
        }

        let popoverId = UUID().uuidString
        let hidePopover = {
            PopoverManager.shared.hidePopover(id: popoverId)
        }
        PopoverManager.shared.showPopover(id: popoverId, content: {
            ModalView(buttons: [
                ModalViewButton(title: NSLocalizedString("Camera", comment: ""), action: {
                    hidePopover()
                    self.showPhotoTaker(source: .camera)
                }),

                ModalViewButton(title: NSLocalizedString("Photo Library", comment: ""), action: {
                    hidePopover()
                    self.showPhotoTaker(source: .photoLibrary)
                })
            ],
            cancel: hidePopover)
        }, withButton: false)
    }

    private func showPhotoTaker(source: UIImagePickerController.SourceType) {
        guard let photo = profilePicture else {
            print("Error, no placeholder image, so cannot edit picture")
            return
        }

        PhotoCaptureController.show(reportID: "", source: source, photoToEdit: photo) { controller, pictureId in

            self.profilePicture = self.getPicture(documentId: pictureId)
            controller.hide()
        }
    }

    private func getPicture(documentId: String?) -> PhotoViewModel? {
        guard let documentId = documentId else { return nil }
        let photos = photoQueryManager.photoViewModels(imagesId: [documentId])
        return photos.first
    }

    private func showOffDutyConfirmation() {
        let endDutyTime = Date()
        guard let startDuty = getDutyStartForCurrentUser(),
            startDuty.status == .onDuty else { return }

        self.startDuty = startDuty
        plannedOffDutyTime = endDutyTime
        dutyReports = dutyReportsForCurrentUser(startDutyTime: startDuty.date, endDutyTime: endDutyTime)
        showingPatrolSummaryView = true
    }

    private func getDutyStartForCurrentUser() -> DutyChangeViewModel? {
        guard let user = settings.realmUser else {
            print("Bad state")
            return nil
        }
        let userEmail = user.emailAddress
        let predicate = NSPredicate(format: "user.email = %@", userEmail)

        let realmDutyChanges = settings.realmUser?
            .agencyRealm()?
            .objects(DutyChange.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false) ?? nil

        guard let dutyChanges = realmDutyChanges,
            let dutyChange = dutyChanges.first else { return nil }

        return DutyChangeViewModel(dutyChange: dutyChange)
    }

    private func dutyReportsForCurrentUser(startDutyTime: Date, endDutyTime: Date) -> [ReportViewModel] {
        guard let user = settings.realmUser else {
            print("Bad state")
            return []
        }
        let userEmail = user.emailAddress

        let predicate = NSPredicate(format: "timestamp > %@ AND timestamp < %@ AND reportingOfficer.email = %@",
                                    startDutyTime as NSDate, endDutyTime as NSDate, userEmail)

        let realmReports = settings.realmUser?
            .agencyRealm()?
            .objects(Report.self)
            .filter(predicate)
            .sorted(byKeyPath: "timestamp", ascending: false) ?? nil

        guard let reports = realmReports else { return [] }

        var dutyReports = [ReportViewModel]()
        for report in reports {
            dutyReports.append(ReportViewModel(report))
        }
        return dutyReports
    }
}

struct ProfilePageView_Previews: PreviewProvider {
    static var previews: some View {
        let user = UserViewModel()
        user.email = "test@email.com"
        let name = NameViewModel()
        name.first = "John"
        name.last = "Doe"
        user.name = name

        return
            Group {
                NavigationView {
                    ProfilePageView(user: user,
                                    dutyState: DutyState())
                }
                NavigationView {
                    ProfilePageView(user: user,
                                    dutyState: .sample)
                }
        }
    }
}
