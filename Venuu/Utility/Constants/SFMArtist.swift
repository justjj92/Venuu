//
//  SFMArtist.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmArtist: Codable {

    /** unique Musicbrainz Identifier (MBID), e.g. &lt;em&gt;&amp;quot;b10bbbfc-cf9e-42e0-be17-e2c3e1d2600d&amp;quot;&lt;/em&gt; */
    public var mbid: String?
    /** unique Ticket Master Identifier (TMID), e.g. &lt;em&gt;735610&lt;/em&gt; */
    public var tmid: Int?
    /** the artist&#x27;s name, e.g. &lt;em&gt;&amp;quot;The Beatles&amp;quot;&lt;/em&gt; */
    public var name: String?
    /** the artist&#x27;s sort name, e.g. &lt;em&gt;&amp;quot;Beatles, The&amp;quot;&lt;/em&gt; or &lt;em&gt;&amp;quot;Springsteen, Bruce&amp;quot;&lt;/em&gt; */
    public var sortName: String?
    /** disambiguation to distinguish between artists with same names */
    public var disambiguation: String?
    /** the attribution url */
    public var url: String?

    public init(mbid: String? = nil, tmid: Int? = nil, name: String? = nil, sortName: String? = nil, disambiguation: String? = nil, url: String? = nil) {
        self.mbid = mbid
        self.tmid = tmid
        self.name = name
        self.sortName = sortName
        self.disambiguation = disambiguation
        self.url = url
    }


}
