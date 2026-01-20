'use client'

import { useState } from 'react'

interface ConsentFormProps {
  formData: {
    consent_tos: boolean
    consent_dictionary: boolean
    consent_ai_training: boolean
    is_18_or_older: boolean
    guardian_name?: string
    guardian_email?: string
  }
  onChange: (field: string, value: any) => void
}

export default function ConsentForm({ formData, onChange }: ConsentFormProps) {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold mb-4">Consent & Permissions</h3>
        <p className="text-gray-600 mb-6">
          Please review and accept the following consents to continue. Your contributions
          will help preserve the True Motu language for future generations.
        </p>
      </div>

      <div className="space-y-4">
        {/* Terms of Service */}
        <label className="flex items-start space-x-3 cursor-pointer">
          <input
            type="checkbox"
            checked={formData.consent_tos}
            onChange={(e) => onChange('consent_tos', e.target.checked)}
            className="mt-1 h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
            required
          />
          <span className="text-sm text-gray-700">
            I agree to the{' '}
            <a href="#" className="text-primary-600 hover:underline">
              Terms of Service
            </a>{' '}
            and{' '}
            <a href="#" className="text-primary-600 hover:underline">
              Privacy Policy
            </a>
            <span className="text-red-500"> *</span>
          </span>
        </label>

        {/* Dictionary Usage */}
        <label className="flex items-start space-x-3 cursor-pointer">
          <input
            type="checkbox"
            checked={formData.consent_dictionary}
            onChange={(e) => onChange('consent_dictionary', e.target.checked)}
            className="mt-1 h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
            required
          />
          <span className="text-sm text-gray-700">
            I consent to my contributions being used in the public True Motu dictionary
            and related educational materials
            <span className="text-red-500"> *</span>
          </span>
        </label>

        {/* AI Training */}
        <label className="flex items-start space-x-3 cursor-pointer">
          <input
            type="checkbox"
            checked={formData.consent_ai_training}
            onChange={(e) => onChange('consent_ai_training', e.target.checked)}
            className="mt-1 h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
            required
          />
          <span className="text-sm text-gray-700">
            I consent to my contributions being used to train AI models for Motu language
            preservation and translation
            <span className="text-red-500"> *</span>
          </span>
        </label>
      </div>

      <div className="border-t pt-6 mt-6">
        <h4 className="font-medium mb-4">Age Verification</h4>

        <div className="space-y-3">
          <label className="flex items-center space-x-3 cursor-pointer">
            <input
              type="radio"
              name="age_verification"
              checked={formData.is_18_or_older === true}
              onChange={() => {
                onChange('is_18_or_older', true)
                onChange('guardian_name', '')
                onChange('guardian_email', '')
              }}
              className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300"
              required
            />
            <span className="text-sm text-gray-700">
              I am 18 years of age or older
            </span>
          </label>

          <label className="flex items-center space-x-3 cursor-pointer">
            <input
              type="radio"
              name="age_verification"
              checked={formData.is_18_or_older === false && (formData.guardian_name !== undefined)}
              onChange={() => onChange('is_18_or_older', false)}
              className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300"
            />
            <span className="text-sm text-gray-700">
              I am under 18 (requires guardian consent)
            </span>
          </label>
        </div>

        {formData.is_18_or_older === false && (
          <div className="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-md space-y-4">
            <p className="text-sm text-gray-700">
              Please provide your parent or guardian's information for consent:
            </p>

            <div>
              <label className="label">Guardian Name<span className="text-red-500"> *</span></label>
              <input
                type="text"
                value={formData.guardian_name || ''}
                onChange={(e) => onChange('guardian_name', e.target.value)}
                className="input"
                required
              />
            </div>

            <div>
              <label className="label">Guardian Email<span className="text-red-500"> *</span></label>
              <input
                type="email"
                value={formData.guardian_email || ''}
                onChange={(e) => onChange('guardian_email', e.target.value)}
                className="input"
                required
              />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
