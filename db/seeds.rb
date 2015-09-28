# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# Podcast.delete_all
# ITunesCategory.delete_all
# ITunesImage.delete_all
# FeedImage.delete_all

# 99pi
fi = FeedImage.create(
  url: 'http://cdn.99percentinvisible.org/wp-content/uploads/powerpress/99invisible-logo-1400.jpg',
  link: 'http://99percentinvisible.org/',
  title: '99% Invisible',
  description: '99% Invisible'
)

ii = ITunesImage.create(url: "http://cdn.99percentinvisible.org/wp-content/uploads/powerpress/99invisible-logo-1400.jpg")

ic = ITunesCategory.create(name: 'Arts', subcategories: 'Design')

p = Podcast.create(
  feed_image: fi,
  itunes_image: ii,
  itunes_categories: [ic],
  title: '99% Invisible',
  link: 'http://99percentinvisible.org',
  description: 'A Tiny Radio Show about Design with Roman Mars',
  language: 'en-US',
  managing_editor: 'roman@prx.org (Roman Mars)',
  categories: ['99% Invisible','broadcasting','design','kitchen sisters','radio','radio diaries','radiotopia','recording','sound'].join(', '),
  explicit: false,
  subtitle: 'A tiny radio show about design, architecture & the 99% invisible activity that shapes our world.',
  summary: "Design is everywhere in our lives, perhaps most importantly in the places where we've just stopped noticing. 99% Invisible (99 Percent Invisible) is a weekly exploration of the process and power of design and architecture. From award winning producer Roman Mars, KALW in San Francisco, and Radiotopia from PRX. Learn more: http://99percentinvisible.org\n\nAwesome people saying nice things:\n\"Roman Mars lights the radio.  His pieces conjure other worlds, grapple with big ideas, make sound three dimensional.  They are smart and funny and original. The Kitchen Sisters would like to be Presidents of his Fan Club.\" -The Kitchen Sisters, NPR\n\n\"Highly digging 99% Invisible. One of the best podcasts I've bumped into in a while.\" -Jad Abumrad, Radiolab\n\n\"I love the show. It's wonderful. Actually reminded me of why I love radio.\" -Jonathan Goldstein, CBC's WireTap\n\n\"99% Invisible is completely wonderful…entertaining, and beautifully produced.” -Ira Glass, This American Life\n\nProud member of PRX's Radiotopia.",
  keywords: nil,
  update_period: 'hourly',
  update_frequency: 1,
  update_base: nil,
  copyright: 'Copyright © 2014 Roman Mars. All rights reserved.',
  author: 'Roman Mars',
  owner_name: 'Roman Mars',
  owner_email: 'roman@prx.org',
  prx_uri: 'https://cms.prx.org/api/stories/99999'
)
