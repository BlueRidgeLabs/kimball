# frozen_string_literal: true

# == Schema Information
#
# Table name: carts
#
#  id            :integer          not null, primary key
#  name          :string(255)      default("default")
#  user_id       :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  description   :text(16777215)
#  people_count  :integer          default(0)
#  rapidpro_uuid :string(255)
#  rapidpro_sync :boolean          default(FALSE)
#

# TODO: should be renamed to pool...
class Cart < ApplicationRecord
  belongs_to :user

  has_many :carts_people, dependent: :destroy
  has_many :carts_users, dependent: :destroy

  has_many :users, through: :carts_users
  has_many :people, through: :carts_people
  delegate :size, to: :people

  has_many :comments, as: :commentable, dependent: :destroy

  before_create :set_owner_as_user
  validates :name, length: { in: 3..30 }
  validates :name, uniqueness: { message: 'Pool must have a unique name', case_sensitive: false }

  after_save :update_rapidpro, if: :sync_changed?
  default_scope { includes(:carts_people, :carts_users) }
  # TODO: should have an actioncable update for carts in view

  # keep current cart in carts_users,
  # add validation that it must be unique on scope of user.
  def owner
    user
  end

  # this looks like a decorator, should be elsewhere.
  def name_and_count
    "#{name}: #{people_count}"
  end

  def assign_current_cart(user_id)
    cu = carts_users.find_or_create_by(user_id: user_id)
    cu.set_current_cart
    cu.save
  end

  def add_user(user_id)
    user = User.find(user_id)
    (users << user) unless users.include?(user)
  end

  def remove_person(person_id)
    cart_person = carts_people.find_by(person_id: person_id)
    cart_person.destroy if cart_person.present?
  end

  def people_ids
    people.pluck(:id)
  end

  private

  def sync_changed?
    saved_changes.key?('rapidpro_sync')
  end

  def update_rapidpro
    return if Rails.application.credentials.rapidpro[:token].blank?

    if rapidpro_sync == true
      RapidproGroupJob.perform_async(id, 'create') if rapidpro_uuid.nil?
    else # creating
      RapidproGroupJob.perform_async(id, 'delete')
    end
  end

  def set_owner_as_user
    users << user
  end
end
