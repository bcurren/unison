require File.expand_path("#{File.dirname(__FILE__)}/../../unison_spec_helper")

module Unison
  module Relations
    describe Selection do
      attr_reader :operand, :selection, :predicate, :photo
      before do
        @operand = photos_set
        @predicate = operand[:user_id].eq("nathan")
        @selection = Selection.new(operand, predicate)
      end

      describe "#initialize" do
        it "sets the #operand and #predicate" do
          selection.operand.should == photos_set
          selection.predicate.should == predicate
        end
      end

      describe "#tuple_class" do
        it "delegates to its #operand" do
          selection.tuple_class.should == operand.tuple_class
        end
      end

      describe "#new_tuple" do
        it "delegates to its #operand" do
          attributes = { :id => 'dog_photos', :name => 'Dog Photos' }
          selection.new_tuple(attributes).should == operand.new_tuple(attributes)
        end
      end

      describe "#push" do
        before do
          origin.connection[:users].delete
          origin.connection[:photos].delete
        end

        context "when the Selection contains PrimitiveTuples" do
          before do
            selection.composed_sets.length.should == 1
          end

          it "calls #push on the given Repository with self" do
            origin.fetch(selection).should be_empty
            selection.push
            origin.fetch(selection).should == selection.tuples
          end
        end

        context "when the Selection contains CompositeTuples" do
          before do
            @selection = users_set.join(photos_set).on(photos_set[:user_id].eq(users_set[:id])).where(users_set[:id].eq("nathan"))
            selection.should_not be_empty
            selection.composed_sets.length.should == 2
          end

          it "pushes a SetProjection of each Set represented in the Selection to the given Repository" do
            users_projection = selection.project(users_set)
            photos_projection = selection.project(photos_set)
            mock.proxy(origin).push(users_projection)
            mock.proxy(origin).push(photos_projection)

            users_set.fetch.should be_empty
            photos_set.fetch.should be_empty
            selection.push
            users_set.fetch.should == users_projection.tuples
            photos_set.fetch.should == photos_projection.tuples
          end
        end
      end

      describe "#fetch_sql" do
        context "when #operand is a Set" do
          before do
            @selection = users_set.where(users_set[:id].eq("nathan"))
          end

          it "returns 'select #operand where #predicate'" do
            selection.fetch_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `users`.`hobby`, `users`.`team_id`, `users`.`developer`, `users`.`show_fans`
              FROM `users`
              WHERE `users`.`id` = 'nathan'
            ")
          end
        end

        context "when #operand is a Selection" do
          before do
            @selection = users_set.where(users_set[:id].eq("nathan")).where(users_set[:name].eq("Nathan"))
          end

          it "returns 'select #operand where #predicate'" do
            selection.fetch_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `users`.`hobby`, `users`.`team_id`, `users`.`developer`, `users`.`show_fans`
              FROM `users`
              WHERE `users`.`id` = 'nathan' AND `users`.`name` = 'Nathan'
            ")
          end
        end
      end

      describe "#fetch_arel" do
        it "returns an Arel representation of the relation" do
          selection.fetch_arel.should == operand.fetch_arel.where(predicate.fetch_arel)
        end
      end

      describe "#set" do
        it "delegates to its #operand" do
          selection.set.should == operand.set
        end
      end

      describe "#composed_sets" do
        it "delegates to its #operand" do
          selection.composed_sets.should == operand.composed_sets
        end
      end

      describe "#attribute" do
        it "delegates to #operand" do
          operand_attribute = operand.attribute(:id)
          mock.proxy(operand).attribute(:id)
          selection.attribute(:id).should == operand_attribute
        end
      end

      describe "#has_attribute?" do
        it "delegates to #operand" do
          operand.has_attribute?(:id).should be_true
          mock.proxy(operand).has_attribute?(:id)
          selection.has_attribute?(:id).should be_true
        end
      end

      describe "#merge" do
        it "calls #merge on the #operand" do
          tuple = Photo.new(:id => "photo_100", :user_id => "nathan", :name => "Photo 100")
          operand.find(tuple[:id]).should be_nil
          operand.should_not include(tuple)
          mock.proxy(operand).merge([tuple])

          selection.merge([tuple])

          operand.should include(tuple)
        end
      end

      context "when #retained?" do
        attr_reader :retainer
        before do
          @retainer = Object.new
          selection.retain_with(retainer)
          selection.tuples
        end

        after do
          selection.release_from(retainer)
        end

        context "when the #predicate is updated" do
          attr_reader :user, :new_photos, :old_photos
          before do
            @user = User.find("nathan")
            @predicate = photos_set[:user_id].eq(user.signal(:id))
            @selection = Selection.new(photos_set, predicate).retain_with(retainer)
            @old_photos = selection.tuples.dup
            old_photos.length.should == 2
            @new_photos = [ Photo.create(:id => "photo_100", :user_id => "new_id", :name => "Photo 100"),
                            Photo.create(:id => "photo_101", :user_id => "new_id", :name => "Photo 101") ]
          end

          after do
            selection.release_from(retainer)
          end

          context "for Tuples that match the new Predicate but not the old one" do
            it "inserts the Tuples in the set" do
              new_photos.each{|tuple| selection.tuples.should_not include(tuple)}
              user[:id] = "new_id"
              new_photos.each{|tuple| selection.tuples.should include(tuple)}
            end

            it "triggers the on_insert event" do
              inserted_tuples = []
              selection.on_insert(retainer) do |tuple|
                inserted_tuples << tuple
              end
              user[:id] = "new_id"
              inserted_tuples.should == new_photos
            end

            it "#retains inserted Tuples" do
              new_photos.each{|tuple| tuple.should_not be_retained_by(selection)}
              user[:id] = "new_id"
              new_photos.each{|tuple| tuple.should be_retained_by(selection)}
            end
          end

          context "for Tuples that matched the old Predicate but not the new one" do
            it "deletes the Tuples from the set" do
              old_photos.each{|tuple| selection.tuples.should include(tuple)}
              user[:id] = "new_id"
              old_photos.each{|tuple| selection.tuples.should_not include(tuple)}
            end

            it "triggers the on_delete event for the deleted Tuples" do
              deleted_tuples = []
              selection.on_delete(retainer) do |tuple|
                deleted_tuples << tuple
              end
              user[:id] = "new_id"
              deleted_tuples.should == old_photos
            end

            it "#releases deleted Tuples"  do
              old_photos.each{|tuple| tuple.should be_retained_by(selection)}
              user[:id] = "new_id"
              old_photos.each{|tuple| tuple.should_not be_retained_by(selection)}
            end
          end

          context "for Tuples that match both the old and new Predicates" do
            # TODO: JN/NS - No predicate types currently exist that could allow a tuple to match two different predicates.
            it "keeps the Tuples in the set"
            it "does not trigger the on_insert event for the Tuples"
            it "does not trigger the on_delete event for the Tuples"
            it "continues to retain the Tuples"
          end
        end

        context "when a Tuple is inserted into the #operand" do
          context "when the Tuple matches the #predicate" do
            before do
              @photo = Photo.new(:id => "photo_100", :user_id => "nathan", :name => "Photo 100")
              predicate.eval(photo).should be_true
            end

            it "is added to the objects returned by #tuples" do
              selection.tuples.should_not include(photo)
              photos_set.insert(photo)
              selection.tuples.should include(photo)
            end

            it "triggers the on_insert event" do
              on_insert_tuple = nil
              selection.on_insert(retainer) do |tuple|
                on_insert_tuple = tuple
              end

              photos_set.insert(photo)
              on_insert_tuple.should == photo
            end

            it "is #retained by the Selection" do
              photo.should_not be_retained_by(selection)
              photos_set.insert(photo)
              photo.should be_retained_by(selection)
            end
          end

          context "when the Tuple does not match the #predicate" do
            before do
              @photo = Photo.new(:id => "photo_100", :user_id => 2, :name => "Photo 100")
              predicate.eval(photo).should be_false
            end

            it "is not added to the objects returned by #tuples" do
              selection.tuples.should_not include(photo)
              photos_set.insert(photo)
              selection.tuples.should_not include(photo)
            end

            it "does not trigger the on_insert event" do
              selection.on_insert(retainer) do |tuple|
                raise "Don't taze me"
              end
              photos_set.insert(photo)
            end

            it "is not #retained by the Selection" do
              photo.should_not be_retained_by(selection)
              photos_set.insert(photo)
              photo.should_not be_retained_by(selection)
            end
          end
        end

        context "when a Tuple in the #operand that does not match the #predicate is updated" do
          before do
            @photo = Photo.create(:id => "photo_100", :user_id => 2, :name => "Photo 100")
          end

          context "when the update causes the Tuple to match the #predicate" do
            it "adds the Tuple to the result of #tuples" do
              selection.tuples.should_not include(photo)
              photo[:user_id] = "nathan"
              selection.tuples.should include(photo)
            end

            it "triggers the on_insert event" do
              on_insert_tuple = nil
              selection.on_insert(retainer) do |tuple|
                on_insert_tuple = tuple
              end
              selection.tuples.should_not include(photo)

              photo[:user_id] = "nathan"
              on_insert_tuple.should == photo
            end

            it "is #retained by the Selection" do
              photo.should_not be_retained_by(selection)
              photo[:user_id] = "nathan"
              photo.should be_retained_by(selection)
            end
          end

          context "when the update does not cause the Tuple to match the #predicate" do
            it "does not add the Tuple into the result of #tuples" do
              selection.tuples.should_not include(photo)
              photo[:user_id] = "ross"
              selection.tuples.should_not include(photo)
            end

            it "does not trigger the on_insert event" do
              selection.on_insert(retainer) do |tuple|
                raise "Don't taze me bro"
              end

              photo[:user_id] = "ross"
            end

            it "is not #retained by the Selection" do
              photo.should_not be_retained_by(selection)
              photo[:user_id] = "ross"
              photo.should_not be_retained_by(selection)
            end
          end
        end

        context "when a Tuple is deleted from the #operand" do
          context "when the Tuple matches the #predicate" do
            attr_reader :photo
            before do
              @photo = selection.tuples.first
              predicate.eval(photo).should be_true
            end

            it "is deleted from the objects returned by #tuples" do
              selection.tuples.should include(photo)
              photos_set.delete(photo)
              selection.tuples.should_not include(photo)
            end

            it "triggers the on_delete event" do
              deleted = nil
              selection.on_delete(retainer) do |tuple|
                deleted = tuple
              end

              photos_set.delete(photo)
              deleted.should == photo
            end

            it "#releases the deleted Tuple" do
              photo.should be_retained_by(selection)
              photos_set.delete(photo)
              photo.should_not be_retained_by(selection)
            end
          end

          context "when the Tuple does not match the #predicate" do
            attr_reader :photo
            before do
              @photo = Photo.create(:id => "photo_100", :user_id => "new_id", :name => "Photo 100")
              predicate.eval(photo).should be_false
            end

            it "is not deleted from the objects returned by #tuples" do
              selection.tuples.should_not include(photo)
              photos_set.delete(photo)
              selection.tuples.should_not include(photo)
            end

            it "does not trigger the on_delete event" do
              selection.on_delete(retainer) do |tuple|
                raise "Don't taze me"
              end
              photos_set.delete(photo)
            end
          end
        end
        
        context "when a Tuple that matches the #predicate in the #operand is updated" do
          before do
            @photo = selection.tuples.first
          end

          context "when the update causes the Tuple to not match the #predicate" do
            it "removes the Tuple from the result of #tuples" do
              selection.tuples.should include(photo)
              photo[:user_id] = "ross"
              selection.tuples.should_not include(photo)
            end

            it "triggers the on_delete event" do
              on_delete_tuple = nil
              selection.on_delete(retainer) do |tuple|
                on_delete_tuple = tuple
              end

              photo[:user_id] = "ross"
              on_delete_tuple.should == photo
            end

            it "#releases the deleted Tuple" do
              photo.should be_retained_by(selection)
              photo[:user_id] = "ross"
              photo.should_not be_retained_by(selection)
            end
          end

          context "when the Tuple continues to match the #predicate after the update" do
            it "does not change the size of the result of #tuples" do
              selection.tuples.should include(photo)
              lambda do
                photo[:name] = "New Name"
              end.should_not change {selection.tuples.size}
              selection.tuples.should include(photo)
            end

            it "triggers the on_tuple_update event" do
              arguments = []
              selection.on_tuple_update(retainer) do |tuple, attribute, old_value, new_value|
                arguments.push [tuple, attribute, old_value, new_value]
              end

              old_value = photo[:name]
              new_value = "New Name"
              photo[:name] = new_value
              arguments.should == [[photo, photos_set[:name], old_value, new_value]]
            end

            it "does not trigger the on_insert or on_delete event" do
              selection.on_insert(retainer) do |tuple|
                raise "Don't taze me bro"
              end
              selection.on_delete(retainer) do |tuple|
                raise "Don't taze me bro"
              end

              photo[:name] = "New Name"
            end

            it "does not release_from the deleted Tuple" do
              photo.should be_retained_by(selection)
              photo[:name] = "James Brown"
              photo.should be_retained_by(selection)
            end
          end
        end
      end

      context "when not #retained?" do
        describe "#after_first_retain" do
          attr_reader :retainer
          before do
            @retainer = Object.new
            mock.proxy(selection).after_first_retain
          end

          after do
            selection.release_from(retainer)
          end

          it "retains the Tuples inserted by #initial_read" do
            selection.retain_with(retainer)
            selection.should_not be_empty
            selection.each do |tuple|
              tuple.should be_retained_by(selection)
            end
          end
        end

        describe "#tuples" do
          it "returns all tuples in its #operand for which its #predicate returns true" do
            tuples = selection.tuples
            tuples.size.should == 2
            tuples.each do |tuple|
              tuple[:user_id].should == "nathan"
            end
          end
        end
      end
    end
  end
end