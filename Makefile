SWIG = swig -DSWIGWORDSIZE64
CXX = g++

ARCH = $(shell arch)

LDFLAGS = -Llibs -lpthread -lrt -lgridstore
LDFLAGS_RUBY = -L. -Wl,-Bsymbolic-functions -Wl,-z,relro \
				-rdynamic -Wl,-export-dynamic -ldl -lcrypt -lm -lc

CPPFLAGS = -fPIC -std=c++0x -g -O2
INCLUDES = -Iinclude -Isrc

INCLUDES_RUBY = $(INCLUDES) \
				-I${HOME}/.rvm/rubies/ruby-2.5.3/include/ruby-2.5.0/x86_64-linux \
				-I${HOME}/.rvm/rubies/ruby-2.5.3/include/ruby-2.5.0 

PROGRAM = griddb_ruby.so
EXTRA   =

SOURCES =   src/TimeSeriesProperties.cpp \
			src/ContainerInfo.cpp \
			src/AggregationResult.cpp \
			src/Container.cpp \
			src/Store.cpp \
			src/StoreFactory.cpp \
			src/PartitionController.cpp \
			src/Query.cpp \
			src/QueryAnalysisEntry.cpp \
			src/RowKeyPredicate.cpp \
			src/RowSet.cpp \
			src/TimestampUtils.cpp

all: $(PROGRAM)

SWIG_DEF = src/griddb.i

SWIG_RUBY_SOURCES = src/griddb_ruby.cxx

OBJS = $(SOURCES:.cpp=.o)
SWIG_RUBY_OBJS = $(SWIG_RUBY_SOURCES:.cxx=.o)

$(SWIG_RUBY_SOURCES) : $(SWIG_DEF)
	$(SWIG) -outdir . -o $@ -c++ -ruby $<

.cpp.o:
	$(CXX) $(CPPFLAGS) -c -o $@ $(INCLUDES) $<

$(SWIG_RUBY_OBJS): $(SWIG_RUBY_SOURCES)
	$(CXX) $(CPPFLAGS) -c -o $@ $(INCLUDES_RUBY) $<

$(PROGRAM): $(OBJS) $(SWIG_RUBY_OBJS)
	$(CXX) -shared  -o $@ $(OBJS) $(SWIG_RUBY_OBJS) $(LDFLAGS) $(LDFLAGS_RUBY)

clean:
	rm -rf $(OBJS) $(SWIG_RUBY_OBJS)
	rm -rf $(SWIG_RUBY_SOURCES)
	rm -rf $(PROGRAM) $(EXTRA)
