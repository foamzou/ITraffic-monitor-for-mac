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
        HStack(alignment: .center) {
            VStack(spacing: 0) {
                Spacer().frame(width: 0, height: 1)
                
                HStack() {
                    Text("↗")
                        .font(.system(size: 9))
                    Text(formatBytes(bytes:statusDataModel.totalOutBytes))
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .padding(.leading, -8.0)
                        .frame(width: 45)
                }.frame(width:60, height: 10, alignment: .trailing)
                HStack() {
                    Text("↙")
                        .font(.system(size: 9))
                        .multilineTextAlignment(.trailing)
                    Text(formatBytes(bytes:statusDataModel.totalInBytes))
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .padding(.leading, -8.0)
                        .frame(width: 45.0)
                }.padding(.top, -1.5).frame(width:60, height: 10, alignment: .trailing)
            }
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView()
            .environment(\.sizeCategory, .small)
            
            
            
            
    }
}
