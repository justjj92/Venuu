//
//  FeaturedTabView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI



struct FeaturedTabView: View {
    
    @State var showUpdate = false
    
    var body: some View {
        VStack {
            HStack {

                Spacer()
            } // HStack
            .padding(.horizontal)
            .padding(.top, 30)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing:20) {
                    ForEach(blogArticleData ) { item in
                        GeometryReader { geometry in
                            FeaturedBlogView(blogArticle: item)
                                .rotation3DEffect(Angle(degrees: geometry.frame(in: .global).minX / -20
                                                       ), axis: (x: 0, y: 10.0, z: 0))
                        }
                        .frame(width: 250,height: 250)
                }
            }
            .padding(30)
            .padding(.bottom, 30)
            }

            Spacer()
        }
    }
}

struct Blog_Previews: PreviewProvider {
    static var previews: some View {
        FeaturedTabView()
    }
}

struct FeaturedBlogView: View {
    var blogArticle: blogArticle

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Text(blogArticle.title)
                    .font(.system(size: 30, weight: .bold))
                    .frame(width: 100, alignment: .leading)
                    .foregroundColor(.white)
                Spacer()

            }
            Text(blogArticle.date.uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)

            blogArticle.image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150)

        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .frame(width: 250, height: 250)
        .background(blogArticle.color)
        .cornerRadius(30)
        .shadow(color: blogArticle.color.opacity(0.3), radius: 20, x: 0, y: 20)
    }
}

struct blogArticle: Identifiable {
    var id = UUID()
    var title: String
    var date: String
    var image: Image
    var color: Color
}

let blogArticleData = [
    blogArticle( title: "Blog Post", date: "11/10/22", image: Image("Temp_Header1"), color: Color(.lightGray)),
    blogArticle( title: "Blog Post", date: "11/10/22", image: Image("Temp_Header1"), color: Color(.lightGray)),
    blogArticle( title: "Blog Post", date: "11/10/22", image: Image("Temp_Header1"), color: Color(.lightGray))

]
