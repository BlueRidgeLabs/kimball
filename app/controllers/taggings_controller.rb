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
    'Person'    => Person,
    'V2::Event' => V2::Event
  }.freeze

  # FIXME: Refactor and re-enable cop
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  #
  def create
    klass = TAGGABLE_TYPES.fetch(params[:taggable_type])
    res = false
    if klass && params[:tag].present?
      obj = klass.find(params[:taggable_id])
      tag = params[:tag]
      # if we want owned tags. Not sure we do...
      # res = current_user.tag(obj,with: params[:tagging][:name])
      unless obj.tag_list.include?(tag)
        obj.tag_list.add(tag)
        res = obj.save
        found_tag = klass.tag_counts.find_by(name: tag)
        @tagging = obj.taggings.find_by(tag_id: found_tag.id)
      end
    end

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

  # rubocop:enable Metrics/MethodLength
  def search
    type = params[:type].blank? ? 'Person' : params[:type]
    klass = type.constantize
    @tags = klass.tag_counts.where('name like ?', "%#{params[:q]}%").
            order(taggings_count: :desc)

    # the methods=> :value is needed for tokenfield.
    # https://github.com/sliptree/bootstrap-tokenfield/issues/189
    render json: @tags.to_json(methods: [:value, :label, :type])
  end

end
