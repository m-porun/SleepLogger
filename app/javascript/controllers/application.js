import { Application } from "@hotwired/stimulus"
import CharacterCounter from 'stimulus-character-counter'

const application = Application.start()
application.register('character-counter', CharacterCounter)

// Configure Stimulus development experience
application.debug = process.env.NODE_ENV === 'development'
window.Stimulus   = application

export { application }
