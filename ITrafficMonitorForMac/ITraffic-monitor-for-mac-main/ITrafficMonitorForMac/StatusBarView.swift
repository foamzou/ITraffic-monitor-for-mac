//
//  StatusBarView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var statusDataModel = SharedStore.statusDataModel
    
    var body: some View {
        HStack {
            VStack(spacing: 0) {
                Spacer().frame(width: 0, height: 1, alignment: .trailing)
                HStack() {
                    Text("↑"+formatBytes(bytes: statusDataModel.totalOutBytes))
                        .font(.system(size: 9))
                        .multilineTextAlignment(.trailing)
                }.frame(width:57, height: 12, alignment: .leading)
                HStack {
                    Text("↓"+formatBytes(bytes: statusDataModel.totalInBytes))
                        .font(.system(size: 9))
                        .multilineTextAlignment(.trailing)
                }.padding(.top, -1.5).frame(width:57, height: 12, alignment: .leading)
            }
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView()
            .previewLayout(.sizeThatFits)
            
            
            
    }
}
