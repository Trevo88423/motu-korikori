'use client'

import { ConnectionType, AgeRange } from '@/lib/types'

interface SignupFormProps {
  formData: {
    email: string
    password: string
    confirmPassword?: string
    name: string
    age_range: AgeRange | ''
    locations: string[]
    connection_type: ConnectionType | ''
    who_taught: string
  }
  onChange: (field: string, value: any) => void
  errors: Record<string, string>
}

export default function SignupForm({ formData, onChange, errors }: SignupFormProps) {
  const handleLocationAdd = (location: string) => {
    if (location && !formData.locations.includes(location)) {
      onChange('locations', [...formData.locations, location])
    }
  }

  const handleLocationRemove = (location: string) => {
    onChange('locations', formData.locations.filter(l => l !== location))
  }

  return (
    <div className="space-y-6">
      {/* Account Info */}
      <div>
        <h3 className="text-lg font-semibold mb-4">Account Information</h3>

        <div className="space-y-4">
          <div>
            <label className="label">
              Email<span className="text-red-500"> *</span>
            </label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => onChange('email', e.target.value)}
              className="input"
              required
            />
            {errors.email && <p className="text-sm text-red-600 mt-1">{errors.email}</p>}
          </div>

          <div>
            <label className="label">
              Password<span className="text-red-500"> *</span>
            </label>
            <input
              type="password"
              value={formData.password}
              onChange={(e) => onChange('password', e.target.value)}
              className="input"
              required
              minLength={8}
            />
            <p className="text-xs text-gray-500 mt-1">
              At least 8 characters
            </p>
          </div>

          <div>
            <label className="label">
              Confirm Password<span className="text-red-500"> *</span>
            </label>
            <input
              type="password"
              value={formData.confirmPassword || ''}
              onChange={(e) => onChange('confirmPassword', e.target.value)}
              className="input"
              required
            />
            {errors.confirmPassword && <p className="text-sm text-red-600 mt-1">{errors.confirmPassword}</p>}
          </div>

          <div>
            <label className="label">
              Full Name<span className="text-red-500"> *</span>
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => onChange('name', e.target.value)}
              className="input"
              required
            />
          </div>
        </div>
      </div>

      {/* Demographics */}
      <div className="border-t pt-6">
        <h3 className="text-lg font-semibold mb-4">About You</h3>
        <p className="text-sm text-gray-600 mb-4">
          This information helps us weight contributions appropriately and understand our community.
        </p>

        <div className="space-y-4">
          <div>
            <label className="label">
              Age Range<span className="text-red-500"> *</span>
            </label>
            <select
              value={formData.age_range}
              onChange={(e) => onChange('age_range', e.target.value)}
              className="input"
              required
            >
              <option value="">Select age range</option>
              <option value="under_18">Under 18</option>
              <option value="18_24">18-24</option>
              <option value="25_34">25-34</option>
              <option value="35_44">35-44</option>
              <option value="45_54">45-54</option>
              <option value="55_64">55-64</option>
              <option value="65_plus">65+</option>
              <option value="prefer_not_to_say">Prefer not to say</option>
            </select>
          </div>

          <div>
            <label className="label">
              Connection to True Motu<span className="text-red-500"> *</span>
            </label>
            <select
              value={formData.connection_type}
              onChange={(e) => onChange('connection_type', e.target.value)}
              className="input"
              required
            >
              <option value="">Select your connection</option>
              <option value="native_speaker">Native Speaker (grew up speaking Motu korikori)</option>
              <option value="heritage_speaker">Heritage Speaker (learned from family)</option>
              <option value="second_language">Second Language Learner (fluent)</option>
              <option value="learning_now">Currently Learning</option>
              <option value="researcher">Researcher/Linguist</option>
              <option value="other">Other</option>
            </select>
          </div>

          <div>
            <label className="label">
              Where did you learn/use True Motu? (e.g., Hanuabada, Port Moresby)
            </label>
            <input
              type="text"
              placeholder="Add a location and press Enter"
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault()
                  handleLocationAdd(e.currentTarget.value)
                  e.currentTarget.value = ''
                }
              }}
              className="input"
            />
            {formData.locations.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-2">
                {formData.locations.map((location, index) => (
                  <span
                    key={index}
                    className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-primary-100 text-primary-700"
                  >
                    {location}
                    <button
                      type="button"
                      onClick={() => handleLocationRemove(location)}
                      className="ml-2 text-primary-500 hover:text-primary-700"
                    >
                      &times;
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          <div>
            <label className="label">
              Who taught you True Motu? (optional)
            </label>
            <input
              type="text"
              value={formData.who_taught}
              onChange={(e) => onChange('who_taught', e.target.value)}
              placeholder="e.g., my grandmother, my village elders"
              className="input"
            />
            <p className="text-xs text-gray-500 mt-1">
              This helps us understand transmission patterns of the language
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
