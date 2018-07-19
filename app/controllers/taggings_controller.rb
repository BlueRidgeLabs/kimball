# frozen_string_literal: true

# == Schema Information
#
# Table name: taggings
#
#  id            :integer          not null, primary key
#  taggable_type :string(255)
#  taggable_id   :integer
#  created_by    :integer
#  created_at    :datetime
#  updated_at    :datetime
#  tag_id        :integer
#

class TaggingsController < ApplicationController

  TAGGABLE_TYPES = {
    'Person'          => Person.active,
    'ResearchSession' => ResearchSession
  }.freeze

  # FIXME: Refactor and re-enable cop
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  #
  def create
    klass = TAGGABLE_TYPES.fetch(params[:taggable_type])
    res = false
    if klass && params[:tag].present? && params[:tag] != ''
      obj = klass.includes(:tags, :taggings).find(params[:taggable_id])
      tag = params[:tag].downcase
      # if we want owned tags. Not sure we do...
      # res = current_user.tag(obj,with: params[:tagging][:name])
      unless obj.tags.map(&:name).include?(tag)
        obj.tag_list.add(tag)
        res = obj.save
        # super awkward way of finding the right *kind* of tag
        found_tag = klass.tagged_with(tag).first.tags.select { |t| t.name == tag }.first
        @tagging = obj.taggings.find_by(tag_id: found_tag.id)
      end
    end

    flash[:error] = "Oops, can't add that tag" unless res

    if res
      respond_to do |format|
        format.js {}
      end
    else
      respond_to do |format|
        format.js do
          render text: "console.log('tag save error');
          $('#tagging_name').val('');
          $('input#tag-typeahead').typeahead('val','');"
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength
  def destroy
    @tagging = ActsAsTaggableOn::Tagging.find(params[:id])
    @tagging_id = @tagging.id
    if @tagging.destroy
      respond_to do |format|
        format.js {}
      end
    else
      respond_to do |format|
        format.js { render text: "alert('failed to destroy tag.')" }
      end
    end
  end

  def index
    @tags = Person.active.tag_counts_on(:tags).order('taggings_count DESC')
  end

  # rubocop:enable Metrics/MethodLength
  def search
    klass = params[:type].blank? ? Person.active : TAGGABLE_TYPES.fetch(params[:type])

    # this query is busted. waaaay too big. loads EVERY tag.
    # potentially the solution is to
    # search the tags only, THEN filter through taggings by taggable_type?
    # tags = ActsAsTaggableOn::Tag.where('name like ?',"%#{params[:q]}%")
    # taggings = ActsAsTaggableOn::Tagging.include(:tags).where(taggable_type: klass.to_s, tag_id: tags.map(&:id)).group(:tag_id).count(:tag_id)

    @tags = klass.tag_counts.where('name like ?', "%#{params[:q].downcase}%").
            order(taggings_count: :desc)

    # the methods=> :value is needed for tokenfield.
    # https://github.com/sliptree/bootstrap-tokenfield/issues/189
    render json: @tags.to_json
  end

end
